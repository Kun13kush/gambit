# =========================================================
# NAT Gateway
# =========================================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip"
  }
}

resource "aws_nat_gateway" "gambit" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  depends_on = [
    aws_internet_gateway.gambit
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-nat"
  }
}


# =========================================================
# Private Route Table
# =========================================================

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.gambit.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gambit.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-private-rt"
  }
}


# =========================================================
# Private Subnet Associations
# =========================================================

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_3" {
  subnet_id      = aws_subnet.private_3.id
  route_table_id = aws_route_table.private.id
}