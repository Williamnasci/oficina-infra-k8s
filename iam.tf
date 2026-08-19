# AWS Academy Learner Lab nega iam:CreateRole/iam:PutRolePolicy (mesma
# restricao de iam:CreateUser ja documentada no README) - nao e possivel
# criar uma role/policy escopada especificamente para esta EC2 como este
# repositorio fazia antes. A propria plataforma do Academy pre-provisiona
# um instance profile compartilhado (LabInstanceProfile, sobre a LabRole)
# para exatamente esse caso de uso - EC2 precisando de acesso a servicos
# AWS (aqui: Secrets Manager para publicar o kubeconfig, SSM para acesso
# via Session Manager). Reaproveitamos ele em vez de criar o proprio.
#
# Trade-off real, nao escondido: LabRole tem escopo mais amplo que a role
# customizada anterior (least privilege especifico deste projeto) - e a
# role compartilhada de todo o ambiente do lab, cujas permissoes nao
# controlamos nem podemos restringir (anexar uma policy a ela tambem e
# negado). Aceitavel no contexto de um sandbox academico descartavel; nao
# seria numa conta de producao real.
data "aws_iam_instance_profile" "cluster_host" {
  name = "LabInstanceProfile"
}
