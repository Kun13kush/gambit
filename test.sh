#!/bin/bash
ACCOUNT_ID="732108543574"
ROLE_NAME="GitHubActionsECRRole"

# Create OIDC
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 4f716e2ecad1725e8aa8e289488c6a8b60069174

# Create role with MINIMAL trust policy
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::'$ACCOUNT_ID':oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}'

# Add permissions
aws iam put-role-policy --role-name $ROLE_NAME --policy-name ECRPushPolicy --policy-document file:///dev/stdin << 'EOF'
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": ["ecr:GetAuthorizationToken"],
			"Resource": "*"
		},
		{
			"Effect": "Allow",
			"Action": [
				"ecr:BatchCheckLayerAvailability",
				"ecr:CompleteLayerUpload",
				"ecr:InitiateLayerUpload",
				"ecr:PutImage",
				"ecr:UploadLayerPart"
			],
			"Resource": [
				"arn:aws:ecr:eu-west-2:732108543574:repository/gambit-backend",
				"arn:aws:ecr:eu-west-2:732108543574:repository/gambit-frontend"
			]
		}
	]
}
EOF

echo "✅ Setup complete"
