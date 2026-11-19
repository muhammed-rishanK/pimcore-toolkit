# Data modelling

## Purpose and scope
Designing and changing Pimcore DataObject structures: classes, fields, inheritance, variants, relations, field collections, object bricks, classification stores, localized fields, blocks, folders and hierarchy. Includes the data impact of a change and how to migrate existing objects.

**Use when:** adding, renaming, retyping or removing a field; designing a new class; choosing between bricks, collections and classification store; changing relations or inheritance.
**Do not use when:** only the code that reads an existing field changes.

## Inspect the project first
- Definitions: `var/classes/definition_<Class>.php`, `var/classes/fieldcollections/*.php`, `var/classes/objectbricks/*.php`. These are the source of truth and are usually in git.
- Generated classes in `var/classes/DataObject/` (or the configured path): read-only, regenerated from definitions.
- Class settings: parent class, `allowInherit`, `allowVariants`, `useTraits`, `implementsInterfaces`, `listingParentClass`, `listingUseTraits`, `showVariants`, `encryption`.
- Custom layouts that show or hide the fields, and workflow field permissions.
- Classification store: groups, keys and collections live in the database (`classificationstore_*` tables); check whether the project exports them.
- Who uses each field: `grep -rn "getFieldName\|setFieldName\|'fieldName'"` across `src/`, `bundles/`, `config/`, templates and JS; DataHub and importer configs.
- Data volume: object counts per class with a read-only query or listing count.

## Workflow
1. **Choose the structure** for the need:
   | Need | Use |
   |---|---|
   | Fixed attributes every object has | Plain fields in the class |
   | Attribute sets that depend on a type or category, known at design time | Object bricks |
   | Repeating groups of fields (0..n) | Field collection or block |
   | Many attributes managed by business users, varying per category | Classification store |
   | Translatable text | Localized fields |
   | Link to other objects | Many-to-one / many-to-many object relation; advanced many-to-many when the link needs its own data |
   | Parent product with differing children | Variants with inheritance |
2. **Name fields** consistently with the class (camelCase, no type suffix unless the project uses one), with a clear title and tooltip.
3. **Set behaviour**: mandatory (careful with existing objects), validation regex, default values, `noteditable`, `invisible`, index (`index` flag for query table columns used in conditions), unique.
4. **Analyse impact** on existing objects and every dependant (code, layouts, exports, imports, workflows, search, versions).
5. **Classify the change**: additive, rename, type change, removal, relation change. See rules below.
6. **Plan the migration and rollback**.
7. **Apply** the definition change the project's way: edit the definition in the admin and commit the file, or edit the definition file and run `bin/console pimcore:deployment:classes-rebuild -c` (creates missing classes and updates existing ones; never add `-d`, it deletes classes without a definition file).

## Change rules
- **Additive**: safe. Mandatory new fields break saving of existing objects in the admin until filled; prefer not mandatory, or fill data first.
- **Rename**: Pimcore drops the old column and creates a new one; data is lost. Do add new field, copy data (command with dry-run), switch code, remove old field in a later release.
- **Type change**: column type may change and data may be truncated or lost. Export first, convert explicitly.
- **Removal**: data loss. Export the data, remove all usages, then remove the field.
- **Relations**: changing ownership, allowed classes or making a relation reverse changes where data is stored. Plan both sides.
- **Localized fields**: adding a language adds columns; moving a field into or out of localized fields loses data without a migration.
- **Field collections and bricks**: changing a collection definition affects every class that uses it.

## Best practices
- Model for the queries you will run: filterable fields as plain fields, not in classification store or blocks.
- Avoid very wide classes; split by bricks or related objects when it helps editors and queries.
- Use inheritance on purpose; document which fields inherit.
- Keep field names stable; titles can change freely.

## Common mistakes
- Renaming a field in the admin and losing production data.
- Using blocks for data that must be filtered or exported in bulk (stored serialised).
- Classification store for attributes that every object has.
- Forgetting the classification store config is in the database and not deployed with git.
- Hand-editing generated classes.

## Version notes
- Field types and their class names live in `vendor/pimcore/pimcore/models/DataObject/ClassDefinition/Data/`. Confirm a type exists before using it (for example `reverseObjectRelation` in 11 replaced `nonownerobjects` in 10).
- Pimcore 11 can store definitions under a configurable path; check the project's config before assuming `var/classes`.

## Example
Need: products have different technical attributes per product family, around 15 families, 10 to 40 attributes each, managed by the data team monthly.
Recommendation: classification store with one group per family, because attributes change often and are managed by business users. Alternative: object bricks per family; better for developers and queries, but every change is a deploy. Data impact: none for existing fields; new store is empty until import.

## Validation checklist
- [ ] Every dependant of changed fields listed.
- [ ] Change classified; destructive changes have export, migration and rollback.
- [ ] Mandatory and validation rules checked against existing data.
- [ ] Rebuild and cache steps listed; `-d` not used.

## Expected output
Current model, proposed change (field table), data impact with counts, migration and rollback, code and config that must change with it.
