# Audit-only fallback build recipe. The production-intent manifest uses the
# official image pinned by config.yaml version 2.14.2-1; do not switch build
# mode without a separate compatibility gate.
ARG BUILD_FROM
FROM ${BUILD_FROM}

COPY rootfs /
