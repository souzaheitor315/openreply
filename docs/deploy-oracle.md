# OpenReply na Oracle Cloud Always Free (sem Vercel/Railway)

Este guia instala a sua própria cópia do OpenReply em **uma única VM Ubuntu ARM64**
da Oracle Cloud. A publicação usa Docker Compose, PostgreSQL, Redis, um
worker permanente, agendador (cron) e Caddy para HTTPS automático.
**Não é uma instalação sem supervisão:** o cadastro na Oracle, a criação da VM,
o apontamento DNS, o e-mail de login e a autorização da Meta exigem sua ação.

> Use apenas recursos marcados **Always Free-eligible**. Não faça upgrade para
> Pay As You Go e não use recursos extras sem conferir a cobrança. A Oracle
> pode ficar sem capacidade para VMs grátis ou recuperar instâncias ociosas.
> Mantenha backups externos.

## 1. Abrir conta e criar uma máquina

1. Cadastre-se em https://signup.oraclecloud.com/ e faça a verificação de
   identidade/cartão diretamente na Oracle. **Nunca envie dados do cartão,
   CPF, senhas ou chaves SSH pelo chat.**
2. No painel OCI, crie uma **Compute Instance** na sua **home region**.
3. Escolha uma imagem **Ubuntu ARM64**, formato **VM.Standard.A1.Flex**,
   **2 OCPUs e 12 GB de RAM**, com selo Always Free-eligible.
   A disponibilidade muda de região para região. Não selecione uma opção paga.
4. Use uma subnet pública, atribua IPv4 público e crie/baixe um par de chaves
   SSH. Guarde a chave privada no seu computador, nunca no repositório.
5. Nas regras de entrada (Security List/NSG), permita **TCP 80 e 443**
   de toda a internet; **TCP 22 só do seu IP**, se possível. Confira também
   o firewall do Ubuntu. **Não** abra 3000, 5432 nem 6379 à internet.
6. Configure um hostname gratuito, por exemplo, no https://www.duckdns.org/,
   com registro A apontando para o IPv4 público da VM. Espere o DNS resolver.

## 2. Conectar por SSH

No terminal local (substitua os valores):

```bash
ssh -i /caminho/para/sua-chave.key ubuntu@IP_PUBLICO_DA_VM
```

Algumas imagens Oracle usam outro usuário. Confira as instruções exibidas no
painel OCI para a imagem escolhida.

## 3. Instalar Docker e clonar o repositório

Comandos para **Ubuntu** no terminal da VM (instalação oficial do Docker):

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git python3
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

git clone https://github.com/souzaheitor315/openreply.git
cd openreply
bash scripts/oracle-init.sh
```

O script gera **.env** com senhas aleatórias fortes e permissão 600.
Ele não cria contas externas, não publica senhas e não sobrescreve um .env existente.

## 4. Concluir as configurações privadas

```bash
nano .env
```

Preencha corretamente:

- `SITE_DOMAIN`: domínio completo, sem `https://`, por exemplo `meureply.duckdns.org`.
- `NEXTAUTH_URL`: **https://** seguido exatamente do mesmo domínio.
- `ALLOWED_EMAILS`: seu e-mail, para ninguém desconhecido criar conta no painel.
- Login por e-mail: forneça `EMAIL_SERVER` com um SMTP que você controla
  **ou** `RESEND_API_KEY` + remetente verificado. O OpenReply usa links
  enviados por e-mail; sem um SMTP ou Resend funcional você não conseguirá entrar.
- `EMAIL_FROM`: remetente permitido pelo seu serviço de e-mail.
- Para a **Meta direta**, as variáveis `INSTAGRAM_APP_ID`,
  `INSTAGRAM_APP_SECRET` e `FACEBOOK_APP_SECRET` serão preenchidas mais
  tarde, após criar um aplicativo em https://developers.facebook.com/apps.
  `WEBHOOK_VERIFY_TOKEN` já vem gerado pelo script.

**Atenção:** não altere aleatoriamente `POSTGRES_PASSWORD` nem
`DATABASE_URL`: as duas senhas já foram geradas iguais. Não troque
`ENCRYPTION_KEY` após conectar o Instagram, porque ela protege os tokens.

Para salvar no nano: Ctrl+O, Enter, Ctrl+X.

## 5. Publicar (um comando)

Com DNS pronto e .env corretamente configurado:

```bash
sudo docker compose -f docker-compose.oracle.yml up -d --build
```

Este comando compila a aplicação, inicializa PostgreSQL/Redis, aplica
migrações Prisma, inicia a web, worker e scheduler, e ativa HTTPS pelo Caddy.
O primeiro build pode demorar. Se o certificado HTTPS falhar, confirme o DNS,
o IP público e as portas 80/443 (Oracle e firewall do sistema).

Confira:

```bash
sudo docker compose -f docker-compose.oracle.yml ps
sudo docker compose -f docker-compose.oracle.yml logs --tail=100 web worker caddy
curl -s https://SEU_DOMINIO/api/health
```

Quando tudo estiver operacional, o retorno de `/api/health` deve incluir
`status: "ok"` e `checks.worker.healthy: true`.

## 6. Conectar o Instagram (Meta direta; sem Zernio)

Seu Instagram precisa ser Business ou Creator.
Siga as instruções de `docs/setup.md` a partir de "The Meta app":

- Crie app Meta com **Instagram Login**; convide sua conta profissional como
  testadora e aceite o convite no Instagram.
- OAuth redirect: `https://SEU_DOMINIO/api/instagram/callback`.
- Webhook callback: `https://SEU_DOMINIO/api/webhook`;
  use o `WEBHOOK_VERIFY_TOKEN` guardado no .env.
- Assine os campos `comments` e `messages`; publique o app nos termos
  e níveis de acesso permitidos pela Meta.
- No painel OpenReply, conecte a conta, crie uma campanha com palavra-chave
  `TESTE` e comente de outra conta. Confirme o recebimento no Direct e
  a linha `SENT` no DM Logs.

Para configurações completas da Meta e testes:
https://github.com/souzaheitor315/openreply/blob/main/docs/setup.md

## Manutenção

Atualizar código do GitHub:

```bash
cd ~/openreply
git pull --ff-only
sudo docker compose -f docker-compose.oracle.yml up -d --build
```

Ver logs:

```bash
sudo docker compose -f docker-compose.oracle.yml logs --tail=100 -f
```

Exportar um backup de PostgreSQL **no servidor** (copie o arquivo para fora
da VM em seguida; backups só na VM não protegem contra perda da instância):

```bash
sudo docker compose -f docker-compose.oracle.yml exec -T postgres \
  pg_dump -U openreply openreply > openreply-backup.sql
```

Configure backups regulares com segurança, em armazenamento separado.
O Redis persiste filas, mas PostgreSQL guarda os dados de negócio.
Não salve .env, tokens ou arquivos de backup em repositório público.

## Custos e limitações

O objetivo é pagar R$ 0 por **hospedagem** usando recursos Always Free.
Isso **não garante disponibilidade**, aceitação do cadastro, SMTP gratuito
nem elimina possíveis custos de domínio, serviços opcionais e excedentes.
A forma A1 gratuita é limitada por horas de OCPU e GB-horas; mantenha-se
dentro da cota e não crie recursos tarifáveis.
