FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY src/Ledgerly.Api/Ledgerly.Api.csproj src/Ledgerly.Api/
RUN dotnet restore src/Ledgerly.Api/Ledgerly.Api.csproj
COPY src/Ledgerly.Api/ src/Ledgerly.Api/
RUN dotnet publish src/Ledgerly.Api/Ledgerly.Api.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Ledgerly.Api.dll"]
