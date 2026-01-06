FROM public.ecr.aws/docker/library/gradle:jdk17 as builder

WORKDIR /app
COPY build.gradle.kts settings.gradle.kts ./
COPY src ./src
RUN gradle bootJar --no-daemon

FROM public.ecr.aws/amazoncorretto/amazoncorretto:17-al2023-headless
EXPOSE 8080
WORKDIR /app
COPY --from=builder /app/build/libs/*.jar ./app.jar

CMD ["java", "-jar", "/app/app.jar"]
