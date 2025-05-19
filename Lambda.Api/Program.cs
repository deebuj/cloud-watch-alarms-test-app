using Amazon.CloudWatch;
using Amazon.CloudWatchLogs;
using Amazon.Lambda.AspNetCoreServer.Hosting;
using Microsoft.OpenApi.Models;
using Amazon.Extensions.NETCore.Setup;

var builder = WebApplication.CreateBuilder(args);

// Add AWS Lambda support
builder.Services.AddAWSLambdaHosting(LambdaEventSource.HttpApi);

// Add AWS Services
builder.Services.AddAWSService<IAmazonCloudWatch>();
builder.Services.AddAWSService<IAmazonCloudWatchLogs>();

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

app.Run();
