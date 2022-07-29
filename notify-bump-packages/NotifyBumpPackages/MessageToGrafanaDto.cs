using System.Text.Json.Serialization;

namespace NotifyBumpPackages;

public class MessageToGrafanaDto
{
    [JsonPropertyName("team")]
    public string Team { get; set; } = null!;

    [JsonPropertyName("alert_uid")]
    public Guid AlertUid { get; set; } = Guid.NewGuid();

    [JsonPropertyName("pullRequests")]
    public List<ForgottenPullRequestDto> PullRequests
    {
        get;
        set;
    } = null!;
}