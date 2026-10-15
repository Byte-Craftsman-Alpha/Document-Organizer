# Vaulty 0.3 static Web preview

Run `python3 serve.py` on your own machine and open http://localhost:8080/app/ in a standalone browser tab. Register that exact origin in the supplied Web OAuth client, or deploy the public/ contents on your own HTTPS origin and register it. The public client ID is configured; no client secret is used.

Home, direct sharing and version-aware memory caching are included. Browser cache lasts only for the current session and is not an installed offline PWA. Web Share falls back to downloading files if the browser cannot share them. Persistent encrypted caching, PDF first-page rendering and incoming OS share-target registration are Android features.

This folder serves only public static files, not a custom document backend. Do not serve the workspace root or private signing files. Source: ../vaulty. See ../vaulty/docs/V0_3_UPDATE.md.
