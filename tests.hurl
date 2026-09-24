GET https://bernat.ch/keepalive
HTTP 301
[Asserts]
header "Location" == "https://vincent.bernat.ch/keepalive"

GET https://bernat.im/keepalive
HTTP 301
[Asserts]
header "Location" == "https://vincent.bernat.ch/keepalive"

GET https://vincent.bernat.im/keepalive
HTTP 301
[Asserts]
header "Location" == "https://vincent.bernat.ch/keepalive"

GET http://bernat.ch/keepalive
HTTP 301
[Asserts]
header "Location" == "https://bernat.ch/keepalive"

GET http://bernat.im/keepalive
HTTP 301
[Asserts]
header "Location" == "https://vincent.bernat.ch/keepalive"

GET http://vincent.bernat.im/keepalive
HTTP 301
[Asserts]
header "Location" == "https://vincent.bernat.ch/keepalive"

GET http://vincent.bernat.ch/keepalive
HTTP 301
[Asserts]
header "Location" == "https://vincent.bernat.ch/keepalive"

GET https://vincent.bernat.ch/keepalive
HTTP 200

GET https://vincent.bernat.ch/
HTTP 301
[Asserts]
header "Location" == "/en"

GET https://vincent.bernat.ch/
Accept-Language: fr-CA
HTTP 301
[Asserts]
header "Location" == "/fr"
header "Vary" == "Accept-Language"

GET https://vincent.bernat.ch/
Accept-Language: es, en, fr
HTTP 301
[Asserts]
header "Location" == "/en"
header "Vary" == "Accept-Language"

GET https://vincent.bernat.ch/
Accept-Language: es, fr, en
HTTP 301
[Asserts]
header "Location" == "/fr"
header "Vary" == "Accept-Language"

GET https://vincent.bernat.ch/
Accept-Language: de-DE,de;q=0.9,fr;q=0.8,en;q=0.7
HTTP 301
[Asserts]
header "Location" == "/fr"
header "Vary" == "Accept-Language"

GET https://vincent.bernat.ch/
Accept-Language: zh-Hans,zh;q=0.9
HTTP 301
[Asserts]
header "Location" == "/en"
header "Vary" == "Accept-Language"

GET https://vincent.bernat.ch/hit
HTTP 400
[Asserts]
header "Content-Type" == "image/gif"

GET https://vincent.bernat.ch/$
HTTP 404

GET http://www.luffy.cx/keepalive
HTTP 301
[Asserts]
header "Location" == "https://www.luffy.cx/keepalive"

GET https://www.luffy.cx/keepalive
HTTP 301
[Asserts]
header "Location" == "https://vincent.bernat.ch/keepalive"

GET http://luffy.cx/keepalive
HTTP 301
[Asserts]
header "Location" == "https://www.luffy.cx/keepalive"

GET https://luffy.cx/keepalive
HTTP 301
[Asserts]
header "Location" == "https://www.luffy.cx/keepalive"

GET http://media.luffy.cx/images/favicon.png
HTTP 301
[Asserts]
header "Location" == "https://media.luffy.cx/images/favicon.png"

GET https://media.luffy.cx/images/favicon.png
HTTP 200

GET https://media.bernat.ch/images/favicon.png
HTTP 200

HEAD https://media.bernat.ch/videos/2018-self-hosted-videos/240p_4_001.mp4
HTTP 200
[Asserts]
header "Content-Type" == "video/mp4"

GET https://bernat.ch/.well-known/webfinger
HTTP 404

GET https://bernat.ch/.well-known/webfinger?resource=acct:vincent@bernat.ch
HTTP 302
[Asserts]
header "Location" == "https://hachyderm.io/.well-known/webfinger?resource=acct:vbernat@hachyderm.io"

GET https://vincent.bernat.ch/.well-known/atproto-did
HTTP 200

# Skip except on web03.luffy.cx
GET https://comments.luffy.cx/?uri=%2Ffr%2Fblog%2F2018-routage-l3-hyperviseur&nested_limit=5
HTTP 200

# Skip except on web03.luffy.cx
GET https://comments.luffy.cx/?uri=%2Ffr%2Fblog%2F2018-nothing&nested_limit=5
HTTP 200

GET http://une-oasis-une-ecole.fr/projet
HTTP 301
[Asserts]
header "Location" == "https://www.une-oasis-une-ecole.fr/projet"

GET https://une-oasis-une-ecole.fr/projet
HTTP 301
[Asserts]
header "Location" == "https://www.une-oasis-une-ecole.fr/projet"

GET https://www.une-oasis-une-ecole.fr/projet
HTTP 200

GET http://media.une-oasis-une-ecole.fr/images/l/favicon.png
HTTP 301
[Asserts]
header "Location" == "https://media.une-oasis-une-ecole.fr/images/l/favicon.png"

GET https://media.une-oasis-une-ecole.fr/images/l/favicon.png
HTTP 200

GET http://haproxy.debian.net/haproxy.css
HTTP 301
[Asserts]
header "Location" == "https://haproxy.debian.net/haproxy.css"

GET https://haproxy.debian.net/haproxy.css
HTTP 200

GET http://haproxy.debian.net/dists/stretch-backports-1.9/Release
HTTP 200

GET https://haproxy.debian.net/dists/stretch-backports-1.9/Release
HTTP 200

GET http://xxxxx.pages.luffy.cx
HTTP 301
[Asserts]
header "Location" == "https://xxxxx.pages.luffy.cx/"

GET https://xxxxx.pages.luffy.cx
HTTP 404

GET https://pages.luffy.cx
HTTP 403

# Skip except on web02.luffy.cx
GET https://goatcounter.luffy.cx/api/v0/me
HTTP 401

# Skip except on web02.luffy.cx
GET https://p37551.ssh.luffy.cx/en/blog
HTTP 401
[Asserts]
header "WWW-Authenticate" == "Basic realm=\"tunnel\""

# Skip except on web02.luffy.cx
GET https://AAAAAAAAAAAAAAAAAAAAAA--1789928654@p37551.ssh.luffy.cx/en/blog
HTTP 401

# Skip except on web02.luffy.cx
GET https://CJwiid6N6gr4eXFWv1XszA--1790272341@p39001.ssh.luffy.cx/en/blog
HTTP 410
