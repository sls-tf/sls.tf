# Tech Stack

## Context

Global tech stack defaults for Agent OS projects, overridable in project-specific `.agent-os/product/tech-stack.md`.

- App Framework:
- Language: TypeScript 5.9+
- Primary Database: RDS Aurora MySQL 8 or DynamoDB
- ORM: TypeORM
- JavaScript Framework: React latest stable
- Build Tool: Vite
- Import Strategy: Node.js modules
- Package Manager: npm
- Node Version: 22 LTS
- CSS Framework: Standard ES Modules
- UI Components: MUI latest
- UI Installation: npm i
- Font Provider: Google Fonts
- Font Loading: Self-hosted for performance
- Icons: Lucide React components
- Application Hosting: AWS
- Hosting Region: eu-west-2
- Database Hosting: RDS Aurora MySQL or DynamoDB
- Database Backups: Daily automated
- Asset Storage: Amazon S3
- CDN: CloudFront
- Asset Access: Private with signed URLs
- CI/CD Platform: AWS CodePipelines
- CI/CD Trigger: Push to branches
- Tests: Run before deployment
- Production Environment: main branch
- Staging Environment: test branch
