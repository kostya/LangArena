rm -rf ./cache
cd c && rm ./bin_*; rm -rf ./base64 ./cJSON; cd -
cd cpp && rm ./bin_*; rm -rf ./simdjson ./base64;  cd -
cd crystal && rm ./bin_*; cd -
cd csharp && rm -rf ./bin ./obj; cd -
cd golang && rm ./bin_*; cd -
cd java && rm -rf ./target; cd -
cd kotlin && rm -rf ./build; cd -
cd rust && rm -rf ./target; cd -
cd swift && rm -rf ./.build; cd -
cd typescript && rm -rf ./dist ./dist-bun ./dist-bun-max ./dist-deno ./dist-aggressive; cd -
cd zig && rm -rf ./zig-out ./.zig-cache; cd -
