using Microsoft.AspNetCore.Authorization;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace CoopCore.Api.Security;

public sealed class AuthorizeDocumentFilter : IDocumentFilter
{
    public void Apply(OpenApiDocument swaggerDoc, DocumentFilterContext context)
    {
        foreach (var apiDescription in context.ApiDescriptions)
        {
            var metadata = apiDescription.ActionDescriptor.EndpointMetadata;

            if (metadata.OfType<IAllowAnonymous>().Any() ||
                !metadata.OfType<IAuthorizeData>().Any() ||
                string.IsNullOrWhiteSpace(apiDescription.RelativePath) ||
                string.IsNullOrWhiteSpace(apiDescription.HttpMethod))
            {
                continue;
            }

            var path = "/" + apiDescription.RelativePath.TrimEnd('/');

            var method = MapHttpMethod(apiDescription.HttpMethod);

            if (!swaggerDoc.Paths.TryGetValue(path, out var pathItem) ||
                method is null ||
                pathItem.Operations is null ||
                !pathItem.Operations.TryGetValue(method, out var operation))
            {
                continue;
            }

            operation.Security ??= new List<OpenApiSecurityRequirement>();
            operation.Security.Add(new OpenApiSecurityRequirement
            {
                [new OpenApiSecuritySchemeReference("Bearer", swaggerDoc, null!)] = new List<string>()
            });
        }
    }

    private static HttpMethod? MapHttpMethod(string httpMethod)
    {
        return httpMethod.ToUpperInvariant() switch
        {
            "GET" => HttpMethod.Get,
            "POST" => HttpMethod.Post,
            "PUT" => HttpMethod.Put,
            "PATCH" => HttpMethod.Patch,
            "DELETE" => HttpMethod.Delete,
            "HEAD" => HttpMethod.Head,
            "OPTIONS" => HttpMethod.Options,
            "TRACE" => HttpMethod.Trace,
            _ => null
        };
    }
}
