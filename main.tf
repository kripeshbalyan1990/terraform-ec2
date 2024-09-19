resource "aws_vpc" "tf_vpc" {
  cidr_block =  var.vpc_cidr
}

resource "aws_subnet" "public_sub1" {
  vpc_id = aws_vpc.tf_vpc
  cidr_block = var.sub1_cidr
  availability_zone = "ap-south-1a"

  #gives the public ip to instances launched in this subnet 
  #Basically makes it a public subnet. 
  #If value is given false it will become a private subnet. (default is false)
  map_public_ip_on_launch = true 
}

resource "aws_subnet" "public_sub2" {
  vpc_id = aws_vpc.tf_vpc
  cidr_block = var.sub2_cidr
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true 
}

resource "aws_internet_gateway" "tf_vpc_igw" {
  vpc_id = aws_vpc.tf_vpc.id
}

resource "aws_route_table" "tf_rt" {
  vpc_id = aws_vpc.tf_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf_vpc_igw.id
  }
}

resource "aws_route_table_association" "tf_rt_subnet1" {
  subnet_id = aws_subnet.public_sub1.id
  route_table_id = aws_route_table.tf_rt.id
}

resource "aws_route_table_association" "tf_rt_subnet2" {
  subnet_id = aws_subnet.public_sub2.id
  route_table_id = aws_route_table.tf_rt.id
}

#-----instance-level------

resource "aws_security_group" "tf_sg" {
  name = "tf_sg"
  description = "security group for the instances"
  vpc_id = aws_vpc.tf_vpc.id
  ingress {
    description = "HTTP from tf_vpc"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH from tf_vpc"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name ="tf_sg"
  }
}

resource "aws_instance" "tf_instance1" {
  ami = "ami-0522ab6e1ddcc7055"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.tf_sg.id]
  subnet_id = aws_subnet.public_sub1.id
}

resource "aws_instance" "tf_instance2" {
  ami = "ami-0522ab6e1ddcc7055"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.tf_sg.id]
  subnet_id = aws_subnet.public_sub2.id
}

#---Global-load-balancer-------

#costs money
resource "aws_lb" "tf_alb" {
  name = "tf_alb"
  internal = false
  load_balancer_type = "application"
  
  security_groups = [ aws_security_group.tf_sg.id ] #A separate sg should be created
  subnets = [aws_subnet.public_sub1.id, aws_subnet.public_sub2.id]

  tags = {
    Name = "tf_alb"
  }
}

#Lb forwards the request to a target group
resource "aws_lb_target_group" "tf_tg" {
  name = "tf_tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.tf_vpc.id

  health_check {
    #path is the address on which the instance is available
    path = "/"
    port = "traffic-port"
  }
}

#Attach instances to target group
#use count or map to create multiple attachments dynamically
resource "aws_lb_target_group_attachment" "tf_tg_attach1" {
  target_group_arn = aws_lb_target_group.tf_tg.arn
  target_id = aws_instance.tf_instance1
  port = 80
}

resource "aws_lb_target_group_attachment" "tf_tg_attach2" {
  target_group_arn = aws_lb_target_group.tf_tg.arn
  target_id = aws_instance.tf_instance2
  port = 80
}

#kind of policy/mechanism for the lb
resource "aws_lb_listener" "tf_lb_listener" {
  load_balancer_arn = aws_lb.tf_alb.arn
  port = 80
  protocol = "HTTP"

  default_action { #forward/redirect to target group
    target_group_arn = aws_lb_target_group.tf_tg.arn
    type = "forward"
  }
}

resource "aws_s3_bucket" "tf_bucket" {
  bucket = "tf-bucket-test-kripesh-balyan"
}