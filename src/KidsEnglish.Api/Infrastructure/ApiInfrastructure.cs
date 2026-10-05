using System.Security.Claims;
using FluentValidation;
using KidsEnglish.Application.Abstractions;
using KidsEnglish.Application.Common;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace KidsEnglish.Api.Infrastructure;

internal class CurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    public Guid ParentId
    {
        get
        {
            var sub = accessor.HttpContext?.User.FindFirstValue("sub");
            return Guid.TryParse(sub, out var id) ? id : throw new AuthenticationFailedException("Not authenticated.");
        }
    }
}

/// <summary>Maps application exceptions to RFC 7807 ProblemDetails. Never leaks internals or request bodies.</summary>
internal class ApiExceptionHandler(IProblemDetailsService problems, ILogger<ApiExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext ctx, Exception ex, CancellationToken ct)
    {
        var (status, title) = ex switch
        {
            ValidationException => (StatusCodes.Status400BadRequest, "Validation failed"),
            NotFoundException => (StatusCodes.Status404NotFound, "Not found"),
            ConflictException => (StatusCodes.Status409Conflict, "Conflict"),
            AuthenticationFailedException => (StatusCodes.Status401Unauthorized, "Authentication failed"),
            _ => (StatusCodes.Status500InternalServerError, "Server error")
        };

        if (status == StatusCodes.Status500InternalServerError)
            logger.LogError(ex, "Unhandled exception");

        ProblemDetails pd = new() { Status = status, Title = title };
        if (ex is ValidationException ve)
            pd.Extensions["errors"] = ve.Errors.GroupBy(e => e.PropertyName)
                .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray());
        else if (status != StatusCodes.Status500InternalServerError)
            pd.Detail = ex.Message;

        ctx.Response.StatusCode = status;
        return await problems.TryWriteAsync(new ProblemDetailsContext { HttpContext = ctx, ProblemDetails = pd, Exception = ex });
    }
}
