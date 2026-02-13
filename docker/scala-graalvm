FROM benchmarks:graalvm

ARG version
RUN wget -O scala.tar.gz "https://github.com/scala/scala3/releases/download/${version}/scala3-${version}-x86_64-pc-linux.tar.gz" \
    && mkdir -p /opt/scala \
    && tar -xzf scala.tar.gz -C /opt/scala --strip-components=1 \
    && rm scala.tar.gz

ENV PATH="/opt/scala/bin:$PATH"

ARG sbtversion
RUN wget https://github.com/sbt/sbt/releases/download/v$sbtversion/sbt-$sbtversion.zip \
    && unzip sbt-$sbtversion.zip \
    && rm sbt-$sbtversion.zip
ENV PATH="/opt/sbt/bin:$PATH"
