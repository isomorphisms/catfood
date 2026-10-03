# Business Chinese follower pointer

This is a coordination pointer, not an AICI acceptance job or receipt.

Current arrangement:

- learner source: https://github.com/place-of-honor/learn-toki-pona
- Business Chinese content and distributable APKs/binaries:
  https://github.com/isomorphisms/business-chinese

For now, continue terminal, Android-interface, game, and other reusable
language-learner development in `place-of-honor/learn-toki-pona`. Do not fork
that implementation into `business-chinese`.

Business-Chinese-specific corpus material belongs in `business-chinese`.
When a releasable APK or binary is produced for it, publish the deliverable
there and bind it to the exact learner source commit and SHA-256.

Factor the language learner out only when it is sufficiently independent to
stand on its own and that move is explicitly chosen.
