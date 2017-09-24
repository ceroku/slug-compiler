
## Compile source.tgz into slug.tgz

```
docker run --rm -id \
  -v #{MAIN_PATH}/#{repo_name}/sources/#{newrev}:/tmp/sources \
  -v #{MAIN_PATH}/#{repo_name}/builds/#{build_id}:/tmp/slugs \
  -v #{MAIN_PATH}/#{repo_name}/cache:/tmp/cache \
  slugc:dev bash -c "tar -xzf /tmp/sources/source.tgz && /build"
```

> INPUT: source.tgz came from `git archive #{newrev} --format=tar.gz > "#{SOURCES_PATH}/#{repo_name}/sources/#{newrev}/source.tgz"`

### TODO:
- Test all the buildpacks
