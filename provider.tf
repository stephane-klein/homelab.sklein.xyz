provider "netbird" {
  # Uses NB_PAT environment variable (loaded from .secret via mise)
}

provider "scaleway" {
  # Uses SCW_ACCESS_KEY, SCW_SECRET_KEY, SCW_DEFAULT_ORGANIZATION_ID,
  # SCW_DEFAULT_PROJECT_ID environment variables (loaded from .secret via mise)
}
