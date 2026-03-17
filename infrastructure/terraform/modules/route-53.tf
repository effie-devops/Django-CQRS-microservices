# create public hosted zone
resource "aws_route53_zone" "hosted_zone" {
  name = var.domain_name

  tags = {
    Name = "${var.project_name}-${var.environment}-hosted-zone"
  }
}

# create a record set in route 53
resource "aws_route53_record" "site_domain" {
  zone_id = aws_route53_zone.hosted_zone.zone_id
  name    = var.record_name
  type    = "A"

  alias {
    name                   = aws_lb.application_load_balancer.dns_name
    zone_id                = aws_lb.application_load_balancer.zone_id
    evaluate_target_health = true
  }
}
