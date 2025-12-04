package plugin

import (
	"context"
	"fmt"
	"strings"

	"github.com/spiffe/go-spiffe/v2/spiffeid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/structpb"

	credentialcomposerv1 "github.com/spiffe/spire-plugin-sdk/proto/spire/plugin/server/credentialcomposer/v1"
	"spire-aws-auth-plugin/pkg/models"
	"spire-aws-auth-plugin/pkg/s3rules"
)

// handleAWSAuth orchestrates the authorization flow
func (p *Plugin) handleAWSAuth(spiffeID, requestedAud string, currentAttrs *credentialcomposerv1.JWTSVIDAttributes) (*credentialcomposerv1.ComposeWorkloadJWTSVIDResponse, error) {
	workloadReq, err := parseAudience(spiffeID, requestedAud)
	if err != nil {
		p.logger.Warn("Invalid audience format", "spiffe_id", spiffeID, "aud", requestedAud, "error", err)
		return nil, status.Errorf(codes.InvalidArgument, "invalid audience format: %v", err)
	}

	rules, err := p.fetchRulesForWorkload(context.Background(), spiffeID)
	if err != nil {
		p.logger.Warn("Failed to fetch rules", "spiffe_id", spiffeID, "error", err)
		return nil, status.Error(codes.PermissionDenied, "authorization rules inaccessible")
	}

	if !isAuthorized(workloadReq, rules) {
		p.logger.Error("Authorization denied",
			"spiffe_id", spiffeID,
			"requested_db", workloadReq.ReqCluster,
			"requested_user", workloadReq.ReqUser)
		return nil, status.Error(codes.PermissionDenied, "workload not authorized for requested database parameters")
	}

	newClaims, err := p.constructClaims(workloadReq, currentAttrs.Claims.AsMap())
	if err != nil {
		p.logger.Error("Failed to construct claims", "error", err)
		return nil, status.Errorf(codes.Internal, "failed to recompose claims: %v", err)
	}

	return &credentialcomposerv1.ComposeWorkloadJWTSVIDResponse{
		Attributes: &credentialcomposerv1.JWTSVIDAttributes{
			Claims: newClaims,
		},
	}, nil
}

func parseAudience(spiffeID, aud string) (*models.WorkloadRequest, error) {
	// Expected: SPIFFE/AWSaccountID:DBtype:DBcluster:DBuser
	parts := strings.Split(aud, ":")
	if len(parts) != 4 {
		return nil, fmt.Errorf("expected 4 parts, got %d", len(parts))
	}

	return &models.WorkloadRequest{
		SpiffeID:     spiffeID,
		RawAudience:  aud,
		ReqAccountID: strings.TrimPrefix(parts[0], models.AwsAudiencePrefix),
		ReqDBType:    parts[1],
		ReqCluster:   parts[2],
		ReqUser:      parts[3],
	}, nil
}

func (p *Plugin) fetchRulesForWorkload(ctx context.Context, spiffeID string) ([]models.AuthorizationRule, error) {
	// Derive Key: spiffe://example.org/path -> example.org/path
	s3Key := strings.TrimPrefix(spiffeID, "spiffe://")

	p.mu.RLock()
	bucket := p.config.RulesBucket
	awsCfg := p.awsConfig
	p.mu.RUnlock()

	return s3rules.FetchRules(ctx, awsCfg, bucket, s3Key)
}

func isAuthorized(req *models.WorkloadRequest, rules []models.AuthorizationRule) bool {
	for _, rule := range rules {
		if rule.AWSAccountID == req.ReqAccountID &&
			rule.DBType == req.ReqDBType &&
			rule.DBCluster == req.ReqCluster &&
			rule.DBUser == req.ReqUser {
			return true
		}
	}
	return false
}

func (p *Plugin) constructClaims(req *models.WorkloadRequest, existingClaims map[string]interface{}) (*structpb.Struct, error) {
	p.mu.RLock()
	trustDomain := p.trustDomain
	p.mu.RUnlock()

	if trustDomain == "" {
		return nil, fmt.Errorf("trust domain not configured")
	}

	awsAuthAudience := fmt.Sprintf("%s%s", models.AwsAudiencePrefix, trustDomain)

	var finalAudiences []interface{}
	if existingAud, ok := existingClaims["aud"]; ok {
		switch v := existingAud.(type) {
		case []interface{}:
			finalAudiences = append(finalAudiences, v...)
		case string:
			finalAudiences = append(finalAudiences, v)
		}
	}

	hasAwsAud := false
	for _, a := range finalAudiences {
		if a == awsAuthAudience {
			hasAwsAud = true
			break
		}
	}
	if !hasAwsAud {
		finalAudiences = append(finalAudiences, awsAuthAudience)
	}

	awsTags := map[string]interface{}{
		models.TagKeyPrincipal: map[string]interface{}{
			models.TagKeyTarget: []interface{}{req.ReqDBType},
			models.TagKeyDB:     []interface{}{req.ReqCluster},
			models.TagKeyDBUser: []interface{}{req.ReqUser},
		},
	}

	sourceIdentity := "unknown"
	if id, err := spiffeid.FromString(req.SpiffeID); err == nil {
		cleanPath := strings.TrimPrefix(id.Path(), "/")
		segs := strings.Split(cleanPath, "/")
		if len(segs) >= 4 && segs[0] == "ns" && segs[2] == "sa" {
			sourceIdentity = fmt.Sprintf("%s+%s", segs[1], segs[3])
		}
	}

	existingClaims["aud"] = finalAudiences
	existingClaims["azp"] = awsAuthAudience
	existingClaims[models.ClaimAWSTags] = awsTags
	existingClaims[models.ClaimSourceID] = sourceIdentity

	return structpb.NewStruct(existingClaims)
}
