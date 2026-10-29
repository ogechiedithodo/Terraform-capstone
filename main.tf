
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "portfolio_sg" {
  name        = "oge-portfolio-fresh-sg"
  description = "Allow HTTP traffic to portfolio"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "oge-portfolio-fresh-sg"
  }
}

resource "aws_instance" "portfolio" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.portfolio_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/portfolio-setup.log) 2>&1

    dnf install -y docker nginx

    systemctl enable --now docker

    docker pull ogdev1/oge-portfolio:v1

    docker run -d \
      --name oge-portfolio \
      --restart unless-stopped \
      -p 127.0.0.1:8080:80 \
      ogdev1/oge-portfolio:v1

    cat > /etc/nginx/nginx.conf <<'NGINX'
    user nginx;
    worker_processes auto;
    error_log /var/log/nginx/error.log;
    pid /run/nginx.pid;

    events {
        worker_connections 1024;
    }

    http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        access_log /var/log/nginx/access.log;

        server {
            listen 80 default_server;
            server_name _;

            location / {
                proxy_pass http://127.0.0.1:8080;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
            }
        }
    }
    NGINX

    nginx -t
    systemctl enable --now nginx
    systemctl restart nginx
  EOF

  tags = {
    Name = "oge-portfolio-fresh"
  }
}
