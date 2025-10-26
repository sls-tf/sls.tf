## CSS Style Guide

We use CSS Modules for all component styling.

## Multi-line class names in markup

When applying multiple CSS Module classes, use a multi-line format with each conditional or responsive class on its own line.
Use classnames library or template literals for conditional classes.
Focus and hover states should be defined in the CSS file, not as separate classes in markup.
Custom breakpoint 'xs' represents 400px.

Example of multi-line CSS Module classes:
```
jsx<div className={`
  ${styles.cta}
  ${styles.base}
  ${isDark ? styles.dark : ''}
  ${isActive ? styles.active : ''}
  ${size === 'large' ? styles.large : ''}
`}>
  I'm a call-to-action!
</div>
```
Corresponding CSS Module file (Component.module.css):
```
css.cta {
  @apply bg-gray-50 p-4 rounded cursor-pointer w-full;
}

.cta:hover {
  background-color: #f3f4f6;
}

.dark {
  background-color: #111827;
}

.dark:hover {
  background-color: #1f2937;
}

@media (min-width: 400px) {
  .cta { padding: 1.5rem; }
}

@media (min-width: 640px) {
  .cta {
    padding: 2rem;
    font-weight: 500;
  }
}

@media (min-width: 768px) {
  .cta {
    padding: 2.5rem;
    font-size: 1.125rem;
  }
}
```