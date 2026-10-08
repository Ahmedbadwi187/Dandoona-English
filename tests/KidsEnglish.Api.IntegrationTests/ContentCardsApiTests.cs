using System.Net;
using Shouldly;

namespace KidsEnglish.Api.IntegrationTests;

[Collection("api")]
public class ContentCardsApiTests(ApiFactory factory)
{
    private void Write(string rel, string content)
    {
        var path = Path.Combine(factory.CardsRoot, rel);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, content);
    }

    [Fact]
    public async Task Cards_are_served_to_anyone_as_html_that_may_not_load_or_run_anything()
    {
        Write("little_learners/index.html", "<!doctype html><title>Cards</title>");
        Write("little_learners/animals.html", "<!doctype html><title>Animals</title>");
        var c = factory.CreateClient(); // no token, no cookie
        c.DefaultRequestHeaders.Add("Accept", "text/html");

        var page = await c.GetAsync("/cards/little_learners/animals.html");
        page.StatusCode.ShouldBe(HttpStatusCode.OK);
        page.Content.Headers.ContentType!.MediaType.ShouldBe("text/html");
        page.Headers.GetValues("Content-Security-Policy").Single().ShouldContain("default-src 'none'");
        page.Headers.GetValues("Referrer-Policy").Single().ShouldBe("no-referrer");
        page.Headers.Contains("Set-Cookie").ShouldBeFalse();

        var redirect = await factory.CreateClient(new() { AllowAutoRedirect = false }).GetAsync("/cards");
        redirect.StatusCode.ShouldBe(HttpStatusCode.Redirect);
        redirect.Headers.Location!.ToString().ShouldBe("/cards/little_learners/index.html");
    }

    [Fact]
    public async Task Nothing_but_html_and_nothing_outside_the_folder_is_served()
    {
        Write("little_learners/secret.json", "{}");
        var c = factory.CreateClient();
        (await c.GetAsync("/cards/little_learners/secret.json")).StatusCode.ShouldBe(HttpStatusCode.NotFound);
        (await c.GetAsync("/cards/../appsettings.json")).StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }
}
