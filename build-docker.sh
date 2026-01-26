# correct order to build dependencies
docker compose build base
# docker compose build base_clang base_gcc nodejs java graalvm
# docker compose build rust crystal swift dotnet 
# docker compose build gcc_c gcc_clang golang gccgo clang_c clang_cpp
# docker compose build # build others
