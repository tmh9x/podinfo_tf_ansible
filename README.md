# Provision EC2 mit Terraform und Configure mit Ansible
### Was ist Terraform?
Mit Terraform können wir unsere gesamte Infrastruktur in Code beschreiben, sogar über mehrere Service-Provider hinweg (Beispiel: Server liegen auf AWS, DNS ist von CloudFlare und Datenbank liegt in Azure). Terraform erstellt uns all diese Ressourcen parallel für all diese Provider. Insgesamt sollten wir uns merken, dass Terraform eins der besten Tools ist, um die Infrastruktur vorzubereiten und aufzustellen.
### Was ist Ansible?
Ansible ist ein IT Automatisierungs-Tool. Wir nutzen es beispielsweise, um Virtuelle Maschinen, die wir mit Terraform erstellt haben, zu konfigurieren. Ansible kann ebenso Software deployen und komplexere IT-Tasks, wie Continous Deployment oder Updates übernehmen, ohne dass dabei Ausfallzeit entsteht.

## Tutorial
#### Provision einer EC2 Instanz mit Terraform
Wir werden für das Provisioning der EC2-Instanz wieder Module verwenden. Dazu erstellen wir uns zunächst das VPC-Modul in dem Ordner `modules/voc/main.tf`:
```
variable "cidr" {}
variable "region" {}
variable "az" {}

resource "aws_vpc" "main" {
  cidr_block = var.cidr
  enable_dns_hostnames = true

  tags = {
    Name = "AWS VPC"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id  
}

resource "aws_subnet" "main" {
  vpc_id = aws_vpc.main.id
  cidr_block = aws_vpc.main.cidr_block
  availability_zone = var.az
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
}

resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.route_table.id
}

```
Ganz oben definieren wir die Variablen `cidr`, `region` und `az`, die dann später in der `main.tf` auf oberster Ebene gefüllt werden. In diesem Modul definiere wir für das VPC-Modul einige Ressourcen. Diese Ressourcen sind die folgenden:
- eine aws-vpc-Ressource mit dem Namen main: Diese Ressource erstellt eine neue VPC in AWS mit einem bestimmten CIDR-Block, der durch var.cidr angegeben wird. Die Option enable_dns_hostnames = true erlaubt die DNS-Auflösung innerhalb der VPC.
- eine aws-internet-gateway-Ressource mit dem Namen gateway. Ein Internet Gateway wird für die erstellte VPC angelegt. Dieses Gateway ermöglicht die Kommunikation zwischen den Ressourcen innerhalb der VPC und dem Internet.
- ein aws-Subnet mit dem Namen main: Ein Subnetz wird innerhalb der VPC erstellt. Es verwendet den gleichen CIDR-Block wie die VPC und wird einer spezifischen Verfügbarkeitszone zugeordnet, die durch var.az definiert ist.
- eine aws-Route-Table-Ressource mit dem Namen route_table: Eine Route Table wird für die VPC erstellt. Die Route Table definiert Regeln für den Netzwerkverkehr. Hier wird eine spezifische Regel hinzugefügt, die allen Traffic (0.0.0.0/0) an das Internet Gateway weiterleitet.
- eine aws-route-table-association mit dem Namen route_table_assocation: Diese Ressource assoziiert das zuvor erstellte Subnetz mit der Route Table. Das bedeutet, dass der Traffic aus diesem Subnetz den Regeln der Route Table folgt, insbesondere der Regel, die den Internetzugang über das Gateway ermöglicht.

Wir benötigen aus dem VPC-Modul außerdem zwei Outputs, die wir später noch benötigen. Daher definieren wir in einer `output.tf`-Datei die folgenden Outputs:
```
output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_id" {
  value = aws_subnet.main.id
}
````

Als nächstes erstellen wir ein Modul für die Security-Group. In dieser definieren wir zwei Sicherheitsgruppen, die innerhalb des spezifischen VPCs eingesetzt werden. Diese Sicherheitsgruppen dienen dazu, den Netzwerkzugriff auf Ressourcen zu steuern, die in dieser VPC laufen.
```
variable "vpc_id" {}

resource "aws_security_group" "allow_ssh" {
  name = "allow_ssh"
  description = "Allow SSH traffic"
  vpc_id = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
}

resource "aws_security_group" "allow_http" {
  name = "allow_http"
  description = "Allow HTTP traffic"
  vpc_id = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
}
```
An erster Stelle setzen wir hier die Variable vpc_id, die sich speziell auf die ID des VPCs bezieht, für das wir die Sicherheitsgruppen setzen wollen. Darüber hinaus werden dann für das Modul einzelne Ressourcen erstellt. Das sind die folgenden:
- Die Sicherheitsgruppe für den SSH--Zugriff mit dem Namen `allow-ssh` für das erstellte VPC. Hier wird der `ingress` definiert, wobei der Port 22 geöffnet ist für das TCP-Protokoll. Die `cidr_blocks` sind auf überall eingestellt, ist aber potenziell erstmal unsicher. Der `egress`, wobei zu jeder IP-Adresse erlaubt wird und auf Port `0` gesetzt wird mit dem Protokoll `-1`, d.h. dass alle Protokolle erlaubt sind. 
Dasselbe definieren wir dann für den Verkehr mit HTTP.
Auch für die Security Groups brauchen wir zwei Outputs
```
output "allow_ssh" {
  value = aws_security_group.allow_ssh.id
}

output "allow_http" {
  value = aws_security_group.allow_http.id
}
```
Als nächstes widmen wir uns der `main.tf`, wo wir schlussendlich nochmal das EC2-Modul verwenden für die EC2-Instanzen.
```
provider "aws" {
  alias = "eu"
  region = "eu-central-1"
}

module "vpc" {
  source = "./modules/vpc"
  cidr = "10.0.0.0/16"
  region = "eu-central-1"
  az = "eu-central-1a"
}

module "security_groups" {
  source = "./modules/security_groups"
  vpc_id = module.vpc.vpc_id
}

resource "aws_key_pair" "aws_key" {
  key_name   = "ansible-ssh-key"
  public_key = tls_private_key.key.public_key_openssh
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
}

module "ec2" {
  source = "terraform-aws-modules/ec2-instance/aws"
  count  = var.instance_count
  ami             = var.ami
  instance_type   = var.instance_type
  key_name        = aws_key_pair.aws_key.key_name
  subnet_id       = module.vpc.subnet_id
  vpc_security_group_ids = [module.security_groups.allow_ssh, module.security_groups.allow_http]
  associate_public_ip_address = true
}

output "instance_ids" {
  value = [for instance in module.ec2 : instance.id]
}

output "public_ips" {
  value = [for instance in module.ec2 : instance.public_ip]
}
```
An dieser Stelle definieren wir zunächst den PRovider. Das ist aws mit dem Argument `eu-central-1`. Danach wollen wir das VPC-Modul, das wir definiert haben, zu verwenden. Dabei setzen wir eben die Variablen `cidr`, `region` und `az`. Danach verwenden wir das Security-Groups-Modul, das wir definiert haben, mit der `vpc_id`, von dem VPC, das wir per Modul definiert haben. Der näcshte interessante Schritt sind die Ressourcen `aws_key_pair` und `tls_private_key`. Im Key-Pair setzen wir den Namen und erstellen den public_key mit `tls_private_key.key.public_key_openssh`, wobei der Ressource `tls_private_key` den Algorithmus `RSA`. Als letztes definieren wir dann das EC2-Modul. Hier setzen wir die folgenden Eigenschaften:
- Count: Anzahl der Instanzen, gesteuert durch eine Variable.
- AMI & Instance Type: Amazon Machine Image und der Typ der EC2-Instanz, bestimmt durch Variablen. (gesetzt durch die Variablen in der Datei variables.tf, die wir noch erstellen können. Alternativ können hier die Werte hart gesetzt werden)
- Key Name: Der Name des SSH-Schlüssels für den Zugriff auf die Instanzen. Also das, was wir gerade erstellt haben
- Subnet ID & Security Groups: Bestimmt, in welchem Subnetz die Instanzen erstellt werden und welche Sicherheitsgruppen zugewiesen werden. Das sind genau die, die wir im VPC-Modul definiert haben
- Public IP: Jeder Instanz wird eine öffentliche IP-Adresse zugewiesen.

Diesem Modul wollen wir auch Outputs hinzufügen. Das sind die folgenden:
```
output "instance_ids" {
  value = [for instance in module.ec2 : instance.id]
}

output "public_ips" {
  value = [for instance in module.ec2 : instance.public_ip]
}
```
Diese verwenden wir direkt in unserer `output.tf`-Datei. 
```
output "server-data" {
  value       = [for ip in module.ec2 : {
    ip = ip
  }]
  description = "The public IP and DNS of the servers"
}
```
Hier werden die public-IPs und die DNS-Namen der erstellten EC2-Instanzen angezeigt und steht uns dann als Variable mit dem Namen `server-data` zur Verfügung. (Hint: Brauchen wir später noch ...)
#### Informationen an Ansible übergeben
 Terraform soll uns abgesehen vom Erstellen der Instanzen doch bitte auch die SSH-Keys erstellen und ablegen, damit wir diese für Ansible nutzen können, um uns auf die EC2-Instanzen draufzuwählen. In Ansible benötigt man dazu ein inventory-File, wo dann die Hosts-Dateien und die Verbindungsoptionen drin sind. Da wir die EC2-Instanzen mit Terraform dynamisch erstellen, wollen wir auch diese Informationen mit Terraform dynamisch für Ansible bereitstellen. Dazu erstellen wir zunächst zwei Dateien. Als Erstes die `inventory.tf`
 ```
 resource "local_sensitive_file" "private_key" {
  content = tls_private_key.key.private_key_pem
  filename          = format("%s/%s/%s", abspath(path.root), ".ssh", "ansible-ssh-key.pem")
  file_permission   = "0600"
}

resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tftpl", {
    ip_addrs = [for ip in module.ec2: ip.public_ip]
    ssh_keyfile = local_sensitive_file.private_key.filename
  })
  filename = format("%s/%s", abspath(path.root), "inventory.ini")
}
 ```
 An dieser Stelle nutzen wir Terraform, um zwei lokale Dateien zu erstellen, die für die Verwendung mit Ansible wichtig sind: einen privaten SSH-Schlüssel und eine Ansible Inventardatei. Diese Dateien werden somit automatisch generiert, um die KOnfiguration und das Management zu erleichtern. Wir starten mit der Erklärung:
 - die Ressource `local_sensitive_file` mit dem Namen `private_key`: Diese Ressource erstellt eine Datei für den privaten SSH-Schlüssel auf deinem lokalen System. content: Der Inhalt dieser Datei ist der private Schlüssel (private_key_pem), der durch die Ressource tls_private_key erzeugt wird. Dieser Schlüssel wird im PEM-Format gespeichert.
filename: Der Dateiname und Pfad der Schlüsseldatei werden mit der format-Funktion zusammengesetzt, die den absoluten Pfad zum Root-Verzeichnis des Terraform-Projekts (abspath(path.root)), das Unterverzeichnis .ssh und den Dateinamen ansible-ssh-key.pem verwendet.
file_permission: Die Dateiberechtigungen werden auf 0600 gesetzt, um sicherzustellen, dass nur der Dateibesitzer lesen und schreiben kann, was für private Schlüssel erforderlich ist.
- die Ressource `local_file` mit dem Namen `ansible_inventory`: Diese Ressource verwendet die Terraform-Funktion templatefile, um eine Ansible Inventardatei zu generieren, die Informationen über die erstellten EC2-Instanzen und den Pfad zum SSH-Schlüssel enthält. content: Die templatefile-Funktion lädt eine Vorlagendatei (inventory.tftpl) und füllt diese mit dynamischen Daten:
ip_addrs: Eine Liste der öffentlichen IP-Adressen der EC2-Instanzen, die vom ec2-Modul bereitgestellt werden.
ssh_keyfile: Der Pfad zur Datei des privaten Schlüssels, wie oben erstellt.
filename: Der Dateiname und Pfad der Inventardatei werden ähnlich wie beim privaten Schlüssel erstellt. Die Datei inventory.ini wird im Root-Verzeichnis des Terraform-Projekts gespeichert.
Jetzt schauen wir uns natürlich nochmal die `inventory.tftpl`-Datei an, die eben durch unserer `inventory.tf-Datei dynamisch gefüllt werden soll
```
[aws_ec2]
%{ for addr in ip_addrs ~}
${addr}
%{ endfor ~}

[aws_ec2:vars]
ansible_ssh_user=ec2-user
ansible_ssh_private_key_file=${ssh_keyfile}
```
Das ist irgendwie so eine Textvorlage, um eine dynamische Ansible Inventardatei zu erzeugen. Diese wird dann genutzt, um die Verwaltung der EC2-Instanzen über Ansible zu erleichtern. Hier wird eben als erstes die Host-Gruppe `aws_ec2`-User definiert, wo wir uns die ip_addresses ziehen. Außerdem werden die `aws_ec2:vars` definiert, mit dem ssh-user und dem jeweiligen Key, aus dem Key-File. (Das ist der .ssh-Ordner später nachdem wir ein tf apply ausgeführt haben). 
Wir können jetzt einfach ein `tf init`, `tf plan` und `tf apply` ausführen. Hoffentlich ist nun die `inventory.ini` erzeugt worden :-) 

#### Webserver Konfiguration mit Ansible
Als nächstes erstellen wir uns ein Verzeichnis mit dem Namen `ansible` in unserem Verzeichnis. In diesem Verzeichnis füge bitte die folgenden Zeilen zu einer `ansible.cfg` hinzu:
```
[defaults]
inventory=../inventory.ini
host_key_checking = False
```
Was bedeuten denn nun diese Zeilen? Naja wir definieren zunächst die `inventory.ini` Datei als die Inventory-Datei, wo unsere Ansible-Konfigurationen, wie Hosts drin sind. Außerdem stellen wir das `host_key_checking` auf false, so dass die Überprüfung des SSH-Host-Schlüssel deaktiviert ist. Wenn host_key_checking auf False gesetzt ist, deaktiviert Ansible die Überprüfung der SSH-Schlüssel der Hosts, die es zu verwalten versucht. Normalerweise, wenn man sich zum ersten Mal über SSH mit einem Host verbindet, fragt SSH, ob man den öffentlichen Schlüssel des Hosts akzeptieren und speichern möchte. Diese Schlüssel werden in der Datei known_hosts des Benutzers gespeichert. Bei zukünftigen Verbindungen prüft SSH, ob der gespeicherte Schlüssel mit dem des Hosts übereinstimmt, um sicherzustellen, dass keine Man-in-the-Middle-Angriffe stattfinden. Diese Einstellung ist oft nützlich in dynamischen Umgebungen wie Cloud-Deployments, wo IP-Adressen und damit verbundene Host-Schlüssel häufig wechseln können, oder in Testumgebungen, wo Bequemlichkeit über strikte Sicherheitsmaßnahmen priorisiert wird. In Produktionsumgebungen ist es jedoch im Allgemeinen sicherer, diese Überprüfung aktiviert zu lassen.

Jetzt können wir mal prüfen, ob wir mit Ansible die Instanzen anpingen können. Führe den folgenden Befehl aus: `ansible -m ping aws_ec2`. Danach soltlen Success-Meldungen hoffentlich erscheinen.

##### Webserver konfigurieren
Als nächstes wollen wir ein Playbook mit dem NAmen `playbook.yaml` schreiben, um den Webserver zu konfigurieren. Dazu schreiben wir das folgende hinein:
```
- hosts: aws_ec2
  become: yes
  tasks:
    - name: Update apt cache and install Nginx
      yum:
        name: nginx
        state: latest
        update_cache: yes

    - name: Start nginx
      service:
        name: nginx
        state: started
```
Das Playbook wird auf allen Hosts ausgeführt, die in der Gruppe aws_ec2 in der Ansible-Inventardatei aufgeführt sind. become: yes: Diese Direktive weist Ansible an, für die Ausführung der Aufgaben in diesem Playbook Berechtigungen zu eskalieren (typischerweise wird sudo verwendet, um Aufgaben als root auszuführen). Das ist nützlich für Aufgaben, die Administratorrechte benötigen, wie das Installieren von Software oder das Starten von Systemdiensten. Das Playbook enthält zwei Hauptaufgaben:

1. Update yum cache and install Nginx
name: Update yum cache and install Nginx: Dies ist eine Beschreibung dessen, was der Task tut. 
yum:: Dieses Modul wird verwendet, um Pakete auf Systemen zu verwalten, die den yum-Paketmanager verwenden (typisch für CentOS oder RHEL). Hier wird es verwendet, um nginx zu installieren.
name: nginx: Gibt an, dass das Paket nginx installiert oder aktualisiert werden soll.
state: latest: Stellt sicher, dass die neueste Version von Nginx installiert ist.
update_cache: yes: Vor der Installation wird der Paketindex aktualisiert, ähnlich wie apt update bei Debian-basierten Systemen.
2. Start nginx
name: Start nginx: Beschreibt den Task, der darauf abzielt, den Nginx-Dienst zu starten.
service:: Das service-Modul wird verwendet, um zu steuern, dass Dienste auf dem Host gestartet, gestoppt oder neu gestartet werden.
name: nginx: Der Name des Dienstes, der verwaltet wird.
state: started: Gibt an, dass der Dienst gestartet sein sollte.

Ausführen könnt ihr das Playbook mit dem Befehl: `ansible-playbook playbook.yaml`

## Aufgabe:
Schreibt das Playbook bitte so um, dass ihr das PodInfo-Image drauf laufen lasst (wie in der Hausaufgabe am Dienstag).
