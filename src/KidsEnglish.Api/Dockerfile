FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /repo
COPY global.json Directory.Build.props* ./
COPY src/KidsEnglish.Domain/*.csproj src/KidsEnglish.Domain/
COPY src/KidsEnglish.Application/*.csproj src/KidsEnglish.Application/
COPY src/KidsEnglish.Infrastructure/*.csproj src/KidsEnglish.Infrastructure/
COPY src/KidsEnglish.Api/*.csproj src/KidsEnglish.Api/
RUN dotnet restore src/KidsEnglish.Api
COPY src/ src/
RUN dotnet publish src/KidsEnglish.Api -c Release -o /out --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /out .
USER $APP_UID
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "KidsEnglish.Api.dll"]
