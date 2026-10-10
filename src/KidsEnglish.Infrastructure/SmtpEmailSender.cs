using System.Net;
using System.Net.Mail;
using KidsEnglish.Application.Abstractions;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace KidsEnglish.Infrastructure;

/// <summary>The "Email" section of appsettings. With no Host the messages are only written to the log (see DevEmailSender).</summary>
public class EmailOptions
{
    public const string Section = "Email";

    /// <summary>The SMTP server, for example smtp.gmail.com or the host's own mail server. Empty = do not send.</summary>
    public string Host { get; set; } = "";
    public int Port { get; set; } = 587;

    /// <summary>STARTTLS on port 587 (the usual) or SSL on 465.</summary>
    public bool EnableSsl { get; set; } = true;
    public string UserName { get; set; } = "";
    public string Password { get; set; } = "";

    /// <summary>The address messages come from (must be allowed by the SMTP account).</summary>
    public string FromAddress { get; set; } = "";
    public string FromName { get; set; } = "Dandoona English";
}

/// <summary>Sends the messages through the SMTP server named in appsettings.</summary>
internal sealed class SmtpEmailSender(IOptions<EmailOptions> options, ILogger<SmtpEmailSender> log) : IEmailSender
{
    public async Task SendAsync(EmailMessage message, CancellationToken ct)
    {
        var o = options.Value;
        using var mail = new MailMessage
        {
            From = new MailAddress(string.IsNullOrWhiteSpace(o.FromAddress) ? o.UserName : o.FromAddress, o.FromName),
            Subject = message.Subject,
            Body = message.Body,
            IsBodyHtml = false,
        };
        mail.To.Add(message.To);
        using var client = new SmtpClient(o.Host, o.Port)
        {
            EnableSsl = o.EnableSsl,
            DeliveryMethod = SmtpDeliveryMethod.Network,
            Timeout = 15_000,
            Credentials = string.IsNullOrWhiteSpace(o.UserName) ? null : new NetworkCredential(o.UserName, o.Password),
        };
        try
        {
            await client.SendMailAsync(mail, ct);
        }
        catch (Exception e)
        {
            // never leaks the address or the code into the response; the caller decides what the user sees
            log.LogError(e, "E-mail to {Domain} could not be sent", message.To[(message.To.IndexOf('@') + 1)..]);
            throw;
        }
    }
}
