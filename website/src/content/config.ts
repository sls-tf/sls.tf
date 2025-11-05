import { defineCollection, z } from 'astro:content';

const docs = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string().optional(),
    description: z.string().optional(),
    template: z.string().optional(),
    sidebar: z.object({
      order: z.number().optional(),
      label: z.string().optional(),
      badge: z.string().optional(),
      badgeVariant: z.enum(['note', 'tip', 'caution', 'danger', 'success', 'default']).optional()
    }).optional(),
    prev: z.boolean().optional(),
    next: z.boolean().optional(),
    editUrl: z.string().optional(),
    lastUpdated: z.date().optional(),
    tableOfContents: z.boolean().optional(),
    pagefind: z.boolean().optional()
  })
});

export const collections = {
  docs,
};