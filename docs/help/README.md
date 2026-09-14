# Cat Food help pages

Cat Food help is part of delivery, not an afterthought. When a Cat Food entry exposes a command, API, protocol, or other user-facing control surface, keep a short checked-in reference here and expose it through `./catfood help`.

A help page should record, where applicable:

- the commands or API endpoints;
- arguments, methods, request shapes, and important response shapes;
- authentication and configuration;
- small phone/Termux examples that can actually be copied and run;
- target-specific limitations and evidence boundaries;
- the implementation files that are the source of truth.

Do not claim availability merely because an implementation exists. If a listener, package, Android permission, device behavior, or other runtime condition still needs enabling or verification, say so on the help page.

Current topics:

- `gopeed` — [Gopeed REST API](gopeed.md): optional local REST listener, task/config/extension endpoints, authentication, and Termux examples.

From a Cat Food checkout:

```sh
./catfood help
./catfood help gopeed
```
