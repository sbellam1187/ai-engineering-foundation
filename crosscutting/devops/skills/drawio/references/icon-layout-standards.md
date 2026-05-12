# Draw.io Icon and Layout Standards

Use this guide with `skills/drawio/SKILL.md` to produce architecture diagrams with meaningful icons, Azure-library compliance (for Azure workloads), gradient theme consistency, and clean non-overlapping connectors.

## 1) Provider selection

Before generating the diagram:

1. If provider is specified by user, use that provider's icon library.
2. If not specified, ask: `Which cloud/provider should I model (Azure, AWS, GCP, on-prem, or hybrid)?`

## 2) Azure shape library workflow

When provider is Azure, follow this process:

1. Enable Azure shapes in draw.io: `More Shapes` -> `Networking` -> `Azure` -> `Apply`.
2. Use Azure library icons for Azure services instead of generic boxes.
3. Use shape search (`Azure`) to quickly find the exact Azure icon.
4. Optionally start with a template: `Arrange` -> `Insert` -> `Template` -> `Cloud` -> `Azure`.
5. For region boundaries, use background rectangles and send to back (`Arrange` -> `To Back`).

## 3) Icon mapping checklist

Use service icons first. Do not default to blank generic boxes.

| Architecture concept | Preferred icon treatment |
|---|---|
| Database | Provider DB icon or cylinder shape with DB label |
| Cloud/PaaS service | Provider-managed service icon |
| Serverless function | Provider function icon (Azure Functions / AWS Lambda / GCP Functions) |
| Messaging bus | Service bus/queue/topic icon |
| Kubernetes | Cluster icon plus workload/service icons |
| API gateway | Gateway/API management icon |
| Storage | Blob/object storage icon |

Fallback if icon is not available:

- Use rounded node card with clear service label.
- Add a short category prefix in label: `DB:`, `BUS:`, `FUNC:`, `K8S:`.
- Keep gradient theme colors and consistent size.

## 4) Gradient theme tokens

Apply these colors across nodes, containers, and connectors.

| Token | Hex | Usage |
|---|---|---|
| `GRADIENT_START` | `#0078D2` | Main fill start color |
| `GRADIENT_END` | `#0061AB` | Main fill end color |
| `GRADIENT_BORDER` | `#004F8D` | Borders for gradient nodes |
| `GRADIENT_TEXT` | `#FFFFFF` | Node text on gradient fill |
| `BLUE_EDGE` | `#1F5E94` | Arrow and connector color |
| `BLUE_EDGE_STRONG` | `#0B4F8A` | Highlighted critical path |

## 5) Recommended style snippets

Gradient baseline node:

```xml
style="rounded=1;whiteSpace=wrap;html=1;fillColor=#0078d2;gradientColor=#0061ab;gradientDirection=south;strokeColor=#004f8d;fontColor=#ffffff;"
```

Gradient database fallback:

```xml
style="shape=cylinder3;whiteSpace=wrap;html=1;fillColor=#0078d2;gradientColor=#0061ab;gradientDirection=south;strokeColor=#004f8d;fontColor=#ffffff;"
```

Gradient container option:

```xml
style="rounded=1;whiteSpace=wrap;html=1;fillColor=#0078d2;gradientColor=#0061ab;gradientDirection=south;strokeColor=#004f8d;fontColor=#ffffff;dashed=0;"
```

## 6) Connector style and anti-overlap rules

Default connector style:

```xml
style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#1F5E94;endArrow=block;endFill=1;"
```

Use these rules for clean routing:

1. Keep a minimum gap of 40px horizontally and 30px vertically between nodes.
2. Align nodes to a grid before adding connectors.
3. Prefer one flow direction per diagram: left-to-right or top-to-bottom.
4. Use orthogonal/elbow connectors instead of straight diagonal lines.
5. Add waypoints (`mxPoint`) where two connectors would otherwise overlap.
6. Use separate lanes for request and response arrows.
7. Reposition nodes if more than two connectors intersect in one area.
8. Label long connectors so readers can follow paths without visual clutter.

Example edge with waypoints:

```xml
<mxCell id="e1" value="" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#1F5E94;endArrow=block;endFill=1;" edge="1" source="2" target="3" parent="1">
  <mxGeometry relative="1" as="geometry">
    <Array as="points">
      <mxPoint x="420" y="180"/>
      <mxPoint x="420" y="300"/>
    </Array>
  </mxGeometry>
</mxCell>
```

## 7) Example prompt patterns

- `Create an Azure architecture diagram with Azure Functions, Service Bus, AKS, and Azure SQL icons from the Azure shape library. Use gradient theme and avoid overlapping arrows.`
- `Create an AWS architecture diagram for Lambda, SQS, EKS, and RDS using provider icons and orthogonal connectors with no overlap.`
- `Create a hybrid architecture diagram using cloud icons where possible and gradient themed fallback cards otherwise.`
