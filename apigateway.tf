# API Gateway HTTP API v2 - roteamento hibrido (ADR-0004 no oficina-api):
# poucas rotas explicitas (auth, health) + proxy protegido para o resto da
# aplicacao. O gateway so decide quem entra, nao para onde cada endpoint
# interno vai - a aplicacao continua dona do seu proprio contrato (Swagger).

# --- Lookups cross-repo: funcoes Lambda de autenticacao (oficina-lambda-auth) ---
# Mesmo padrao usado em oficina-lambda-auth/terraform/main.tf para o secret do
# RDS: lookup por nome, sem acoplar os dois states diretamente.
data "aws_lambda_function" "auth_login" {
  function_name = "oficina-auth-login"
}

data "aws_lambda_function" "auth_authorizer" {
  function_name = "oficina-auth-authorizer"
}

resource "aws_apigatewayv2_api" "main" {
  name          = "oficina-api-gateway"
  protocol_type = "HTTP"
}

resource "aws_cloudwatch_log_group" "api_gateway_access_logs" {
  name              = "/aws/apigateway/oficina-api-gateway"
  retention_in_days = var.log_retention_days
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_access_logs.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      ip                      = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      authorizerError         = "$context.authorizer.error"
    })
  }
}

# --- Rota publica: POST /auth/login -> Lambda auth-login -----------------

resource "aws_apigatewayv2_integration" "auth_login" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = data.aws_lambda_function.auth_login.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "auth_login" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /auth/login"
  target    = "integrations/${aws_apigatewayv2_integration.auth_login.id}"
}

resource "aws_lambda_permission" "apigw_invoke_auth_login" {
  statement_id  = "AllowAPIGatewayInvokeAuthLogin"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.auth_login.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*/auth/login"
}

# --- Authorizer: valida o JWT (HS256) via Lambda auth-authorizer ---------
# REQUEST (nao TOKEN) e CUSTOM (nao JWT nativo) porque o token e assinado com
# segredo simetrico por uma Lambda propria, nao por um issuer OIDC/JWKS (ver
# ADR-0004). enable_simple_responses=true porque a Lambda retorna o formato
# simples {isAuthorized, context}, nao um IAM policy document completo.
resource "aws_apigatewayv2_authorizer" "lambda_auth_verifier" {
  api_id                            = aws_apigatewayv2_api.main.id
  authorizer_type                   = "REQUEST"
  name                              = "oficina-jwt-authorizer"
  authorizer_uri                    = data.aws_lambda_function.auth_authorizer.invoke_arn
  identity_sources                  = ["$request.header.Authorization"]
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  authorizer_result_ttl_in_seconds  = 300
}

resource "aws_lambda_permission" "apigw_invoke_auth_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.auth_authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.lambda_auth_verifier.id}"
}

# --- Rota publica: GET /health -> aplicacao (NodePort na EC2) ------------
# Integracao separada da rota protegida (nao reaproveita app_proxy) porque o
# HTTP_PROXY com {proxy} na URI so faz sentido quando a rota tem o parametro
# {proxy+}; /health e um caminho fixo.

resource "aws_apigatewayv2_integration" "app_health" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "GET"
  integration_uri    = "http://${aws_instance.cluster_host.public_ip}:${var.app_node_port}/health"

  # Propaga o requestId do Gateway como header para a aplicacao. O logger
  # (nestjs-pino, ver oficina-api) usa esse header como correlation ID em vez
  # de gerar um novo - correlaciona os access logs do Gateway com os logs da
  # aplicacao no Datadog usando o mesmo ID.
  request_parameters = {
    "overwrite:header.x-request-id" = "$context.requestId"
  }
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.app_health.id}"
}

# --- Rota protegida: ANY /{proxy+} -> aplicacao, atras do authorizer -----

resource "aws_apigatewayv2_integration" "app_proxy" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = "http://${aws_instance.cluster_host.public_ip}:${var.app_node_port}/{proxy}"

  # Ver comentario na integracao app_health - mesmo motivo.
  request_parameters = {
    "overwrite:header.x-request-id" = "$context.requestId"
  }
}

resource "aws_apigatewayv2_route" "app_protected" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "ANY /{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.app_proxy.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda_auth_verifier.id
}
