resource "aws_vpc" "fay_vpc" {
  cidr_block = var.cidr_vpc
}

resource "aws_subnet" "first_subnet" {
  vpc_id                  = aws_vpc.fay_vpc.id
  cidr_block              = var.subnet1_cidr
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "first_subnet"
  }
}

resource "aws_subnet" "second_subnet" {
  vpc_id                  = aws_vpc.fay_vpc.id
  cidr_block              = var.subnet2_cidr
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "second_subnet"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.fay_vpc.id
}
resource "aws_route_table" "myrtw" {
  vpc_id = aws_vpc.fay_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "igw"
  }
}
resource "aws_route_table_association" "rtw1" {
  subnet_id      = aws_subnet.first_subnet.id
  route_table_id = aws_route_table.myrtw.id
}
resource "aws_route_table_association" "rtw2" {
  subnet_id      = aws_subnet.second_subnet.id
  route_table_id = aws_route_table.myrtw.id
}

resource "aws_security_group" "web-sg" {
  name        = "web-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.fay_vpc.id

  ingress {
    description = "http to VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH TO VPC"
    from_port   = 22
    to_port     = 22
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
    Name = "web-sg"
  }
}
resource "aws_s3_bucket" "backend-remote-dynamo66" {
  bucket = "backend-remote-dynamo66"
  tags = {
    Name        = "Remote_backend"
    Environment = "Dev"
  }
}
resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.backend-remote-dynamo66.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "terraformfay_bucket_public_access_block" {
  bucket = aws_s3_bucket.backend-remote-dynamo66.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
resource "aws_instance" "Terraform_instance" {
  ami                    = "ami-0a0e5d9c7acc336f1"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  subnet_id              = aws_subnet.first_subnet.id
  user_data              = base64encode(file("userdata.sh"))


  tags = {
    Name = "Terraform_instance"
  }
}
resource "aws_instance" "Terraform_instance2" {
  ami                    = "ami-0a0e5d9c7acc336f1"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  subnet_id              = aws_subnet.second_subnet.id
  user_data              = base64encode(file("userdata2.sh"))


  tags = {
    Name = "Terraform_instance2"
  }
}
#create alb
resource "aws_lb" "my-alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web-sg.id]
  subnets            = [aws_subnet.first_subnet.id, aws_subnet.second_subnet.id]
  tags = {
    name = "my-alb"
  }
}

resource "aws_lb_target_group" "my-alb-tg" {
  name     = "my-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.fay_vpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}
resource "aws_alb_target_group_attachment" "tg-attachment1" {
  target_group_arn = aws_lb_target_group.my-alb-tg.arn
  target_id        = aws_instance.Terraform_instance.id
  port             = 80
}
resource "aws_alb_target_group_attachment" "tg-attachment2" {
  target_group_arn = aws_lb_target_group.my-alb-tg.arn
  target_id        = aws_instance.Terraform_instance2.id
  port             = 80
}
resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.my-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.my-alb-tg.arn
    type             = "forward"

  }
}
resource "aws_dynamodb_table" "backend_table" {
  name           = "backend_table"
  billing_mode   = "PAY_PER_REQUEST"
  #read_capacity  = 20
  #write_capacity = 20
  hash_key       = "LockID"
  #range_key      = "GameTitle"

  attribute {
    name = "LockID"
    type = "S"
  }
}  
output "loadbalancerdns" {
  value = aws_lb.my-alb.dns_name
}

