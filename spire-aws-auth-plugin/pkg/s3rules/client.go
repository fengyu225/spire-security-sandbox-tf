package s3rules

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"spire-aws-auth-plugin/pkg/models"
)

// FetchRules retrieves and decodes authorization rules from a S3 object
func FetchRules(ctx context.Context, cfg aws.Config, bucket, key string) ([]models.AuthorizationRule, error) {
	client := s3.NewFromConfig(cfg)

	resp, err := client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var rules []models.AuthorizationRule
	if err := json.NewDecoder(resp.Body).Decode(&rules); err != nil {
		return nil, fmt.Errorf("failed to decode rules json array: %v", err)
	}

	return rules, nil
}
