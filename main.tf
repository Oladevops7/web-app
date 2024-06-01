resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"

}

resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true # specified true to indicated that instances launched into the subnet should be assigned a public IP aaddress 

}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true # specified true to indicated that instances launched into the subnet should be assigned a public IP aaddress 


}
# Attaching internet to the subnets

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id

}

#a route table is a set of rules that determines where network traffic is directed. Each subnet in your AWS VPC is associated with a route table which controls the traffic flow between subnets

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0" # everything should connet to the taget
    gateway_id = aws_internet_gateway.igw.id
  }

}

#Provides a resource to create an association between a route table and a subnet1 or a route table and an internet gateway .
# Subnet 1
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "webSg" {
  name   = "websg"
  vpc_id = aws_vpc.myvpc.id

# In cloud networking, particularly in platforms like AWS, the concept of security groups is used to control the traffic to and from resources like instances (virtual servers) or other services within a virtual private cloud (VPC).
# When you have two subnets within the same VPC, it's common to create separate ingress (incoming traffic) security groups for each subnet. This allows you to define different rules for incoming traffic depending on the subnet. 
  ingress { #HTTP (Hypertext Transfer Protocol) traffic refers to the communication between a client (such as a web browser) and a server using the HTTP protocol.
    description = "HTTP from VPC" #HTTP from VPC": This line provides a description for the rule, indicating that it allows HTTP traffic from within the VPC.
    from_port   = 80 #This specifies that the incoming traffic is allowed on port 80 (HTTP).
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #it can be accessed by anyone

  }
  ingress { #SSH (Secure Shell) traffic refers to the communication between a client and a server using the SSH protocol. SSH is a cryptographic network protocol that provides secure communication over an insecure network. It allows users to securely log in to and remotely control a server or transfer data between computers.
    description = "SSH" # "SSH": This provides a description for the rule, indicating that it allows SSH traffic.
    from_port   = 22 #This specifies that the incoming traffic is allowed on port 22 (SSH).
    to_port     = 22 #This specifies that the traffic is allowed to go to port 22 (SSH).
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #it can be accessed by anyone

  }
  # only need one egress (outgoing traffic) security group per instance or resource
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Web-sg"
  }
}


# By default, when another AWS account uploads an object to your S3 bucket, that account (the object writer) owns the object. Additionally, the object writer has access to the object, and can grant other users access to it using ACLs. Object ACLs can be used when you need to manage permissions at the object level.
# we do not need ACL because we are not creating an object
resource "aws_s3_bucket" "bucket" {
  bucket = "myvpcs3project0147abbsdgzht"

}

resource "aws_instance" "webserver1" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id] #connecting vpc sg with our instance
  subnet_id              = aws_subnet.subnet1.id         # connecting to the created subnet
  user_data              = base64encode(file("userdata.sh"))

}
resource "aws_instance" "webserver2" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id] #connecting vpc sg with our instance
  subnet_id              = aws_subnet.subnet2.id         # connecting to the created subnet
  user_data              = base64encode(file("userdata1.sh"))

}

#Load balancing is the method of distributing network traffic equally across a pool of resources that support an application
resource "aws_lb" "myalb" {
  name               = "myalb"
  internal           = false #false because it's public
  load_balancer_type = "application"
  security_groups    = [aws_security_group.webSg.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id] # allowing the two subnets

  tags = {
    Name = "web"
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "myTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

# we are attaching our target group to our instance
# Provides the ability to register instances and containers with an Application Load Balancer (ALB) or Network Load Balancer (NLB) target group. For attaching resources with Elastic Load Balancer
# Instance 1
resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn #ARN stands for Amazon Resource Name. It is a unique identifier assigned to resources in the Amazon Web Services (AWS) ecosystem. 
  target_id        = aws_instance.webserver1.id
  port             = 80
}
# Instance 2
resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}

# this is used in printing the load balancer dns on the terminal
output "loadbalancerdns" {
  value = aws_lb.myalb.dns_name

}







