# ====================================================================
# STAGE 1: Build the Maven Project
# ====================================================================
FROM maven:3.9.6-eclipse-temurin-17-alpine AS build
WORKDIR /app

# Copy the pom.xml and download project dependencies (cached unless changed)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy the source code
COPY src ./src

# Package the application as an executable JAR, skipping unit tests 
# (Unit tests would fail during docker build since database isn't running)
RUN mvn package -DskipTests -B

# ====================================================================
# STAGE 2: Secure, Lightweight JRE Runtime
# ====================================================================
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Copy the compiled JAR from Stage 1
COPY --from=build /app/target/backend-1.0.0.jar app.jar

# Expose WebFlux port
EXPOSE 8080

# Environment variables with sensible defaults
ENV PORT=8080

# Run the Spring application
ENTRYPOINT ["java", "-Djava.net.preferIPv4Stack=true", "-jar", "app.jar"]
