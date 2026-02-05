# correct order to build dependencies

# build base
docker compose build base
# build level1
docker compose build base_clang base_gcc nodejs java graalvm ldc dotnet
# build all 
docker compose build
