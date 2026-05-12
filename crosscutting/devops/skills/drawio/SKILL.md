---
name: drawio
description: Generate draw.io diagrams as .drawio files with service-appropriate icons, requested gradient styling, and clean non-overlapping connectors; optionally export to PNG/SVG/PDF with embedded XML
allowed-tools: Bash, Write
---

# Draw.io Diagram Skill

Generate draw.io diagrams as native `.drawio` files. Optionally export to PNG, SVG, or PDF with the diagram XML embedded (so the exported file remains editable in draw.io).

## Cloud context first (required)

Before generating architecture diagrams, identify the target platform:

1. If the user already specifies cloud/provider, use that provider's icon set.
2. If the user does not specify cloud/provider, ask: `Which cloud/provider should I model (Azure, AWS, GCP, on-prem, or hybrid)?`
3. Do not assume Azure/AWS/GCP unless explicitly requested.

This ensures icon selection matches the deployment target.

## How to create a diagram

1. **Confirm cloud/provider context** (ask if not explicitly provided)
2. **Generate draw.io XML** in mxGraphModel format for the requested diagram
3. **Apply icon-first modeling** for services and infrastructure components
4. **Apply gradient theme styles** to all nodes and connectors
5. **Route connectors to avoid overlap/crossings** using orthogonal routing and spacing rules
6. **Write the XML** to a `.drawio` file in the current working directory using the Write tool
7. **If the user requested an export format** (png, svg, pdf), export using the draw.io CLI with `--embed-diagram`, then delete the source `.drawio` file
8. **Open the result**: the exported file if exported, or the `.drawio` file otherwise

## Icon-first architecture modeling (required)

Do not render architecture components as generic blank boxes when an appropriate icon exists.

Use iconized shapes for common elements:

- Database: database/cylinder icon
- Cloud/PaaS services: cloud/provider service icons
- Serverless compute: function icons (for example Azure Functions)
- Messaging: service bus/queue/topic icons
- Container orchestration: Kubernetes cluster/pod/service icons

Provider-specific expectation:

- Azure workloads: use official draw.io Azure shape library entries (not generic boxes) for Function App, Service Bus, AKS, SQL/Storage where applicable
- AWS workloads: use AWS architecture icons for Lambda, SQS/SNS, EKS, RDS, etc.
- GCP workloads: use GCP architecture icons for Cloud Functions, Pub/Sub, GKE, Cloud SQL, etc.

## Azure library workflow (required for Azure diagrams)

When the target provider is Azure, use the Azure library workflow from draw.io guidance.

1. Enable the Azure shape library in draw.io via `More Shapes` -> `Networking` -> `Azure` -> `Apply`.
2. Prefer Azure library shapes over generic cards for Azure resources.
3. Use shape search (`Azure`) to find the exact Azure service icon when categories are large.
4. For Azure region/environment boundaries, use rectangle containers behind resources (`Arrange` -> `To Back`) and style them clearly.
5. For quick starts, Azure templates are allowed (`Arrange` -> `Insert` -> `Template` -> `Cloud` -> `Azure`), then customize.

If Azure library icons are unavailable in the current environment, call that out and use clearly labeled fallback cards.

Fallback rule:

- If an icon is unavailable, use a rounded card with a clear service label and a small category badge (DB, BUS, FUNC, K8S).
- Do not use plain unlabeled rectangles for infrastructure elements.

## Gradient theme defaults (required)

Apply this gradient visual theme across the full diagram unless the user requests a different palette.

- Gradient start: `#0078d2`
- Gradient end: `#0061ab`
- Use draw.io style properties: `fillColor=#0078d2;gradientColor=#0061ab;gradientDirection=south;`
- Borders: `#004f8d`
- Node text: `#ffffff`
- Connectors: stroke (`#1F5E94`), arrowheads matching stroke color
- Highlight path (optional): stroke (`#0B4F8A`), slightly thicker line

Keep color contrast readable and use one consistent palette per diagram.

Gradient node style baseline:

```xml
style="rounded=1;whiteSpace=wrap;html=1;fillColor=#0078d2;gradientColor=#0061ab;gradientDirection=south;strokeColor=#004f8d;fontColor=#ffffff;"
```

## No-overlap connector and layout rules (required)

All architecture diagrams must avoid arrow overlap and unnecessary line crossings.

Layout and routing constraints:

1. Use grid alignment and consistent spacing between nodes (minimum 40px horizontal and 30px vertical gap).
2. Prefer left-to-right or top-to-bottom flow; avoid mixed direction unless needed.
3. Use orthogonal connectors (`edgeStyle=orthogonalEdgeStyle`) or elbow connectors for clean turns.
4. Set explicit edge entry/exit points when default routing causes crossings.
5. Route through waypoints when two edges would overlap.
6. Use parallel lanes for bidirectional flows instead of stacking arrows on the same path.
7. Reposition nodes before adding manual edge bends.
8. If crossings are unavoidable in dense diagrams, add bridge-style separation and labels.

Connector style baseline:

```xml
style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#1F5E94;endArrow=block;endFill=1;"
```

## Text wrapping and label fit rules (required)

All text must stay inside its shape boundaries when opened in draw.io.

Rules:

1. Use HTML labels for multi-line content and force line breaks with `&lt;br&gt;` at natural split points (path separators, hyphens, extensions).
2. Do not rely only on automatic wrapping for long tokens (for example filenames like `mezmo-troubleshoot.sh`).
3. For text-bearing vertices, include this baseline style: `whiteSpace=wrap;html=1;overflow=hidden;align=center;verticalAlign=middle;spacing=6;`.
4. Increase shape width/height when the content still appears crowded after adding line breaks.
5. For lists (such as references), prefer explicit one-item-per-line labels with `&lt;br&gt;`.

Label style example:

```xml
<mxCell id="200" value="references/&lt;br&gt;icon-layout-standards.md" style="rounded=1;whiteSpace=wrap;html=1;overflow=hidden;align=center;verticalAlign=middle;spacing=6;" vertex="1" parent="1">
  <mxGeometry x="100" y="100" width="180" height="70" as="geometry"/>
</mxCell>
```

## Choosing the output format

Check the user's request for a format preference. Examples:

- `/drawio create a flowchart` → `flowchart.drawio`
- `/drawio png flowchart for login` → `login-flow.drawio.png`
- `/drawio svg: ER diagram` → `er-diagram.drawio.svg`
- `/drawio pdf architecture overview` → `architecture-overview.drawio.pdf`

If no format is mentioned, just write the `.drawio` file and open it in draw.io. The user can always ask to export later.

### Supported export formats

| Format | Embed XML | Notes |
|--------|-----------|-------|
| `png` | Yes (`-e`) | Viewable everywhere, editable in draw.io |
| `svg` | Yes (`-e`) | Scalable, editable in draw.io |
| `pdf` | Yes (`-e`) | Printable, editable in draw.io |
| `jpg` | No | Lossy, no embedded XML support |

PNG, SVG, and PDF all support `--embed-diagram` — the exported file contains the full diagram XML, so opening it in draw.io recovers the editable diagram.

## draw.io CLI

The draw.io desktop app includes a command-line interface for exporting.

### Locating the CLI

Try `drawio` first (works if on PATH), then fall back to the platform-specific path:

- **macOS**: `/Applications/draw.io.app/Contents/MacOS/draw.io`
- **Linux**: `drawio` (typically on PATH via snap/apt/flatpak)
- **Windows**: `"C:\Program Files\draw.io\draw.io.exe"`

Use `which drawio` (or `where drawio` on Windows) to check if it's on PATH before falling back.

### Export command

```bash
drawio -x -f <format> -e -b 10 -o <output> <input.drawio>
```

Key flags:
- `-x` / `--export`: export mode
- `-f` / `--format`: output format (png, svg, pdf, jpg)
- `-e` / `--embed-diagram`: embed diagram XML in the output (PNG, SVG, PDF only)
- `-o` / `--output`: output file path
- `-b` / `--border`: border width around diagram (default: 0)
- `-t` / `--transparent`: transparent background (PNG only)
- `-s` / `--scale`: scale the diagram size
- `--width` / `--height`: fit into specified dimensions (preserves aspect ratio)
- `-a` / `--all-pages`: export all pages (PDF only)
- `-p` / `--page-index`: select a specific page (1-based)

### Opening the result

- **macOS**: `open <file>`
- **Linux**: `xdg-open <file>`
- **Windows**: `start <file>`

## File naming

- Use a descriptive filename based on the diagram content (e.g., `login-flow`, `database-schema`)
- Use lowercase with hyphens for multi-word names
- For export, use double extensions: `name.drawio.png`, `name.drawio.svg`, `name.drawio.pdf` — this signals the file contains embedded diagram XML
- After a successful export, delete the intermediate `.drawio` file — the exported file contains the full diagram

## Reference files

Use the reference below when creating architecture diagrams with service icons and clean routing:

- [`references/icon-layout-standards.md`](references/icon-layout-standards.md)

## XML format

A `.drawio` file is native mxGraphModel XML. Always generate XML directly — Mermaid and CSV formats require server-side conversion and cannot be saved as native files.

### Basic structure

Every diagram must have this structure:

```xml
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <!-- Diagram cells go here with parent="1" -->
  </root>
</mxGraphModel>
```

- Cell `id="0"` is the root layer
- Cell `id="1"` is the default parent layer
- All diagram elements use `parent="1"` unless using multiple layers

### Common styles

**Rounded rectangle:**
```xml
<mxCell id="2" value="Label" style="rounded=1;whiteSpace=wrap;" vertex="1" parent="1">
  <mxGeometry x="100" y="100" width="120" height="60" as="geometry"/>
</mxCell>
```

**Diamond (decision):**
```xml
<mxCell id="3" value="Condition?" style="rhombus;whiteSpace=wrap;" vertex="1" parent="1">
  <mxGeometry x="100" y="200" width="120" height="80" as="geometry"/>
</mxCell>
```

**Arrow (edge):**
```xml
<mxCell id="4" value="" style="edgeStyle=orthogonalEdgeStyle;" edge="1" source="2" target="3" parent="1">
  <mxGeometry relative="1" as="geometry"/>
</mxCell>
```

**Labeled arrow:**
```xml
<mxCell id="5" value="Yes" style="edgeStyle=orthogonalEdgeStyle;" edge="1" source="3" target="6" parent="1">
  <mxGeometry relative="1" as="geometry"/>
</mxCell>
```

### Useful style properties

| Property | Values | Use for |
|----------|--------|---------|
| `rounded=1` | 0 or 1 | Rounded corners |
| `whiteSpace=wrap` | wrap | Text wrapping |
| `fillColor=#dae8fc` | Hex color | Background color |
| `strokeColor=#6c8ebf` | Hex color | Border color |
| `fontColor=#333333` | Hex color | Text color |
| `shape=cylinder3` | shape name | Database cylinders |
| `shape=mxgraph.flowchart.document` | shape name | Document shapes |
| `ellipse` | style keyword | Circles/ovals |
| `rhombus` | style keyword | Diamonds |
| `edgeStyle=orthogonalEdgeStyle` | style keyword | Right-angle connectors |
| `edgeStyle=elbowEdgeStyle` | style keyword | Elbow connectors |
| `dashed=1` | 0 or 1 | Dashed lines |
| `swimlane` | style keyword | Swimlane containers |

## CRITICAL: XML well-formedness

- **NEVER use double hyphens (`--`) inside XML comments.** `--` is illegal inside `<!-- -->` per the XML spec and causes parse errors. Use single hyphens or rephrase.
- Escape special characters in attribute values: `&amp;`, `&lt;`, `&gt;`, `&quot;`
- Always use unique `id` values for each `mxCell`