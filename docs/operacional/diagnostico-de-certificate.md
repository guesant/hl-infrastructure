# Certificate não Ready

Quando a emissão de TLS é automatizada por ACME, um `Certificate` que não atinge `Ready` indica que a emissão ou renovação não terminou. O serviço pode continuar servindo o certificado anterior ou ficar sem um certificado válido.

A cadeia de recursos normalmente é:

`Certificate` -> `CertificateRequest` -> `Order` -> `Challenge`

Liste esses recursos no mesmo namespace para localizar o elo que parou. Um `Challenge` preso em `pending` costuma indicar DNS ainda não propagado ou credencial sem permissão para escrever no provedor. Antes de investigar o challenge, confirme se o emissor referenciado pelo `Certificate` está `Ready`.

Depois de corrigir a causa, o controlador tenta novamente. Remover uma tentativa travada pode fazer o controlador recriar o `CertificateRequest`, mas essa ação deve ocorrer somente depois de registrar a causa e confirmar que o recurso pai continua correto.

## Relações

- [TLS automático](../aprender/tls-automatico.md) explica o fluxo ACME.
- [ACME](../aprender/seguranca/pki/acme.md) explica o protocolo de emissão.
- [Cert-manager](../aprender/seguranca/pki/cert-manager.md) explica o controlador usado no cluster.
