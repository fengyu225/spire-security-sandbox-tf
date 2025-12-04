package models

const (
	AwsAudiencePrefix = "SPIFFE/"
	ClaimAWSTags      = "https://aws.amazon.com/tags"
	ClaimSourceID     = "https://aws.amazon.com/source_identity"
	TagKeyPrincipal   = "principal_tags"
	TagKeyTarget      = "Target"
	TagKeyDB          = "DB"
	TagKeyDBUser      = "DBuser"
)

// AuthorizationRule represents a single rule fetched from S3
type AuthorizationRule struct {
	SpiffeID     string `json:"spiffe_id"`
	DBType       string `json:"db_type"`
	AWSAccountID string `json:"aws_account_id"`
	DBCluster    string `json:"db_cluster"`
	DBUser       string `json:"db_user"`
}

// WorkloadRequest holds the parsed intent from the requested audience string
type WorkloadRequest struct {
	SpiffeID     string
	RawAudience  string
	ReqAccountID string
	ReqDBType    string
	ReqCluster   string
	ReqUser      string
}
