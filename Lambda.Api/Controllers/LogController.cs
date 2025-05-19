using Microsoft.AspNetCore.Mvc;
using Amazon.CloudWatchLogs;
using Amazon.CloudWatchLogs.Model;

namespace Lambda.Api.Controllers;

[ApiController]
[Route("[controller]")]
public class LogController : ControllerBase
{
    private readonly IAmazonCloudWatchLogs _cloudWatchLogs;
    private readonly ILogger<LogController> _logger;
    private const string LogGroupName = "/aws/lambda/cloud-watch-alarms-test";

    public LogController(IAmazonCloudWatchLogs cloudWatchLogs, ILogger<LogController> logger)
    {
        _cloudWatchLogs = cloudWatchLogs;
        _logger = logger;
    }

    [HttpPost("error")]
    public async Task<IActionResult> LogError([FromBody] string message)
    {
        try
        {
            var logStreamName = $"{DateTime.UtcNow:yyyy/MM/dd}/errors";

            // Log the message to CloudWatch
            await _cloudWatchLogs.PutLogEventsAsync(new PutLogEventsRequest
            {
                LogGroupName = LogGroupName,
                LogStreamName = logStreamName,
                LogEvents = new List<InputLogEvent>
                {
                    new InputLogEvent
                    {
                        Message = message,
                        Timestamp = DateTime.UtcNow
                    }
                }
            });

            _logger.LogError(message); // Also log to Lambda's default logger
            return Ok(new { message = "Error logged successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to log error to CloudWatch");
            return StatusCode(500, new { error = "Failed to log error to CloudWatch" });
        }
    }
}
