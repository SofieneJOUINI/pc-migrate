FROM maven:3.9-eclipse-temurin-{{JAVA_VERSION}} AS MAVEN_BUILD

COPY pom.xml /build/
COPY src /build/src/

WORKDIR /build/
RUN mvn clean package -DskipTests -ntp


FROM eclipse-temurin:{{JAVA_VERSION}}-jre-alpine AS LAYERS_BUILD
WORKDIR application
ARG JAR_FILE=/build/target/*.jar
COPY --from=MAVEN_BUILD ${JAR_FILE} application.jar
RUN java -Djarmode=layertools -jar application.jar extract

FROM eclipse-temurin:{{JAVA_VERSION}}-jre-alpine
WORKDIR application

COPY --from=LAYERS_BUILD application/dependencies/ ./
COPY --from=LAYERS_BUILD application/spring-boot-loader ./
COPY --from=LAYERS_BUILD application/snapshot-dependencies/ ./
COPY --from=LAYERS_BUILD application/application/ ./

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
