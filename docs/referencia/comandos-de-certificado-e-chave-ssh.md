# Comandos de certificado e chave SSH

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `ssh-keygen -t ed25519 -C "email" -f ~/.ssh/id_ed25519` | Configurar autenticação SSH ou uma deploy key. | `ed25519` é mais moderno, seguro e compacto que RSA para o mesmo nível de proteção; `-N ""` gera sem passphrase, conveniente para automação mas reduz a proteção se o arquivo vazar; ajuste `chmod 600` na chave privada depois de criada. |
| `openssl x509 -in cert.pem -text -noout` | Verificar SAN, validade e emissor de um certificado. | `-noout` evita reimprimir o PEM original; sem `-text`, mostra só fingerprint e número de série. Para DER binário, some `-inform der`. |
| `openssl x509 -in cert.pem -noout -enddate` | Auditoria de certificados próximos do vencimento, ou automação de alerta de renovação. | `cut -d= -f2` isola só a data, mais fácil de processar em script e comparar com a data atual. |
| `openssl x509 -in cert.pem -outform der -out cert.der` | Converter PEM (texto) para DER (binário), quando um sistema (Windows, Android) exige esse formato. | PEM é ASCII em base64, portável e legível; DER é binário, mais compacto e menos legível diretamente. |
| `openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout key.pem -out cert.pem -days 365 -addext "subjectAltName=DNS:..."` | Gerar um certificado autoassinado para teste local ou comunicação interna sem CA disponível. | O SAN é obrigatório na prática, navegadores e bibliotecas TLS atuais ignoram o campo `CN` para validar hostname; sem SAN correspondente, a conexão falha mesmo com o certificado "certo". Um certificado autoassinado não passa por cadeia de confiança pública, cada lado precisa confiar nele explicitamente, o mesmo modelo que caracteriza mTLS quando aplicado nos dois sentidos da conexão. |
| `openssl req -new -key private.pem -out request.csr -subj "/CN=example.com"` | Solicitar um certificado assinado por uma autoridade certificadora. | Usa uma chave privada já existente; a CSR gerada nunca deve conter a chave privada, só é enviada à CA. |
| `openssl s_client -connect example.com:443 -showcerts </dev/null \| openssl x509 -text -noout` | Auditar o certificado de um servidor remoto sem baixar o arquivo manualmente. | Conecta, recebe a cadeia apresentada no handshake TLS e mostra o primeiro certificado dela; útil para verificação rápida antes de confiar num alerta de monitoramento externo. |

## Continue por aqui

[TLS](../aprender/seguranca/tls/index.md), [mTLS](../aprender/seguranca/tls/mtls.md) e [TLS automático](../aprender/tls-automatico.md) cobrem o mecanismo de emissão e confiança por trás desses comandos.
