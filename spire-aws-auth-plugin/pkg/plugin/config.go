package plugin

type Config struct {
	RulesBucket string `hcl:"rules_bucket"`
	AWSRegion   string `hcl:"aws_region"`
}
