resource "aws_security_group" "rds" {
  name_prefix = "checkout-rds-sg-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  tags = {
    Name = "checkout-rds-sg"
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "checkout-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "checkout-db-subnet-group"
  }
}

resource "aws_db_instance" "default" {
  identifier = "checkout-db"

  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = "checkoutdb"
  username = "postgres"
  password = "password"

  iam_database_authentication_enabled = true

  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  multi_az               = false

  tags = {
    Target = "rds"
    DB     = "checkout-db"
    DBuser = "testuser"
  }
}