# Contributing

## Bare Minimum
1. Create new branch
2. Change files
3. Update the version for the `DEV_CONTAINER` variable in the [docker-compose.yml](../docker-compose.yml) file to the next version
4. Do a PR
5. Merge the PR
6. Checkout and pull latest main
7. Create a new tag with the latest version.
The tag version starts with a "v", and the `DEV_CONTAINER` version variable does not.
```shell
git checkout main
git pull
git tag -a v<major.minor.incremental> -m <comment>
```
8. Push the tag
```shell
git push --tags
```

NOTE - We only bump the `DEV_CONTAINER` version and cut a tag 
version when the code for the GDC changes. For example, we don't cut new tags for README-only changes.
