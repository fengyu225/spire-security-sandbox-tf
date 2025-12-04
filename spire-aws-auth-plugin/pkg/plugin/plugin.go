package plugin

import (
	"context"
	"fmt"
	"strings"
	"sync"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/hcl"
	"github.com/spiffe/spire-plugin-sdk/pluginsdk"
	credentialcomposerv1 "github.com/spiffe/spire-plugin-sdk/proto/spire/plugin/server/credentialcomposer/v1"
	configv1 "github.com/spiffe/spire-plugin-sdk/proto/spire/service/common/config/v1"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"spire-aws-auth-plugin/pkg/models"
)

type Plugin struct {
	credentialcomposerv1.UnimplementedCredentialComposerServer
	configv1.UnimplementedConfigServer

	mu          sync.RWMutex
	config      *Config
	logger      hclog.Logger
	awsConfig   aws.Config
	trustDomain string
}

func New() *Plugin {
	return &Plugin{}
}

// ComposeWorkloadJWTSVID implements the CredentialComposer interface
func (p *Plugin) ComposeWorkloadJWTSVID(ctx context.Context, req *credentialcomposerv1.ComposeWorkloadJWTSVIDRequest) (*credentialcomposerv1.ComposeWorkloadJWTSVIDResponse, error) {
	if req.Attributes == nil {
		return &credentialcomposerv1.ComposeWorkloadJWTSVIDResponse{Attributes: req.Attributes}, nil
	}

	claims := req.Attributes.Claims.AsMap()
	rawAud, ok := claims["aud"]
	if !ok {
		return &credentialcomposerv1.ComposeWorkloadJWTSVIDResponse{Attributes: req.Attributes}, nil
	}

	var audiences []string
	switch v := rawAud.(type) {
	case []interface{}:
		for _, s := range v {
			audiences = append(audiences, fmt.Sprint(s))
		}
	case string:
		audiences = []string{v}
	}

	for _, aud := range audiences {
		if strings.HasPrefix(aud, models.AwsAudiencePrefix) {
			return p.handleAWSAuth(req.SpiffeId, aud, req.Attributes)
		}
	}

	return &credentialcomposerv1.ComposeWorkloadJWTSVIDResponse{Attributes: req.Attributes}, nil
}

// Configure implements the Config interface
func (p *Plugin) Configure(ctx context.Context, req *configv1.ConfigureRequest) (*configv1.ConfigureResponse, error) {
	configParsed := new(Config)
	if err := hcl.Decode(configParsed, req.HclConfiguration); err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "failed to decode configuration: %v", err)
	}

	p.mu.Lock()
	defer p.mu.Unlock()
	p.config = configParsed

	if req.CoreConfiguration != nil {
		p.trustDomain = req.CoreConfiguration.TrustDomain
	}

	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(configParsed.AWSRegion))
	if err != nil {
		p.logger.Error("Failed to load AWS SDK config", "error", err)
		return nil, status.Errorf(codes.Internal, "failed to load AWS config: %v", err)
	}
	p.awsConfig = cfg

	p.logger.Info("AWS Auth Plugin Configured",
		"rules_bucket", configParsed.RulesBucket,
		"region", configParsed.AWSRegion,
		"trust_domain", p.trustDomain)

	return &configv1.ConfigureResponse{}, nil
}

func (p *Plugin) SetLogger(logger hclog.Logger)                           { p.logger = logger }
func (p *Plugin) BrokerHostServices(broker pluginsdk.ServiceBroker) error { return nil }

// Boilerplate unimplemented methods
func (p *Plugin) ComposeServerX509CA(context.Context, *credentialcomposerv1.ComposeServerX509CARequest) (*credentialcomposerv1.ComposeServerX509CAResponse, error) {
	return &credentialcomposerv1.ComposeServerX509CAResponse{}, nil
}
func (p *Plugin) ComposeServerX509SVID(context.Context, *credentialcomposerv1.ComposeServerX509SVIDRequest) (*credentialcomposerv1.ComposeServerX509SVIDResponse, error) {
	return &credentialcomposerv1.ComposeServerX509SVIDResponse{}, nil
}
func (p *Plugin) ComposeAgentX509SVID(context.Context, *credentialcomposerv1.ComposeAgentX509SVIDRequest) (*credentialcomposerv1.ComposeAgentX509SVIDResponse, error) {
	return &credentialcomposerv1.ComposeAgentX509SVIDResponse{}, nil
}
func (p *Plugin) ComposeWorkloadX509SVID(context.Context, *credentialcomposerv1.ComposeWorkloadX509SVIDRequest) (*credentialcomposerv1.ComposeWorkloadX509SVIDResponse, error) {
	return &credentialcomposerv1.ComposeWorkloadX509SVIDResponse{}, nil
}
