import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import tailwind from '@astrojs/tailwind';

export default defineConfig({
  site: 'https://sls.tf',
  integrations: [
    starlight({
      title: 'sls.tf',
      description: 'Serverless Framework to Terraform Conversion Module',
      social: {
        github: 'https://github.com/your-org/sls.tf',
        twitter: 'https://twitter.com/your-handle'
      },
      editLink: {
        url: 'https://github.com/your-org/sls.tf/edit/main/website/src/content/docs/{slug}'
      },
      sidebar: [
        {
          label: 'Getting Started',
          items: [
            { label: 'Introduction', link: '/docs/introduction' },
            { label: 'Quick Start', link: '/docs/quick-start' },
            { label: 'Installation', link: '/docs/installation' },
            { label: 'Configuration', link: '/docs/configuration' }
          ]
        },
        {
          label: 'Features',
          items: [
            { label: 'Lambda Functions', link: '/docs/features/lambda-functions' },
            { label: 'API Gateway', link: '/docs/features/api-gateway' },
            { label: 'DynamoDB', link: '/docs/features/dynamodb' },
            { label: 'Event Sources', link: '/docs/features/event-sources' },
            { label: 'TypeScript Support', link: '/docs/features/typescript' },
            { label: 'Variable Resolution', link: '/docs/features/variable-resolution' }
          ]
        },
        {
          label: 'Advanced',
          items: [
            { label: 'Custom Resources', link: '/docs/advanced/custom-resources' },
            { label: 'IAM Roles', link: '/docs/advanced/iam-roles' },
            { label: 'EventBridge Integration', link: '/docs/advanced/eventbridge' },
            { label: 'Route 53 & Domains', link: '/docs/advanced/domains' },
            { label: 'LocalStack Development', link: '/docs/advanced/localstack' }
          ]
        },
        {
          label: 'Migration',
          items: [
            { label: 'Elemental Service Conversion', link: '/docs/migration/elemental-conversion' },
            { label: 'Serverless Framework Migration', link: '/docs/migration/serverless-migration' },
            { label: 'Terraform Import', link: '/docs/migration/terraform-import' }
          ]
        },
        {
          label: 'API Reference',
          items: [
            { label: 'Variables', link: '/docs/api/variables' },
            { label: 'Outputs', link: '/docs/api/outputs' },
            { label: 'Resource Types', link: '/docs/api/resource-types' }
          ]
        },
        {
          label: 'Examples',
          items: [
            { label: 'Basic Lambda Service', link: '/docs/examples/basic-service' },
            { label: 'API Gateway Service', link: '/docs/examples/api-service' },
            { label: 'Event-Driven Architecture', link: '/docs/examples/event-driven' },
            { label: 'TypeScript Configuration', link: '/docs/examples/typescript-config' }
          ]
        }
      ],
      customCss: [
        './src/styles/custom.css'
      ]
    }),
    tailwind({
      applyBaseStyles: false
    })
  ],
  output: 'static',
  base: process.env.NODE_ENV === 'production' ? '/sls.tf/' : '/',
  trailingSlash: 'never'
});