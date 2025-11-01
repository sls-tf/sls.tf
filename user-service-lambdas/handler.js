const AWS = require('aws-sdk');

// Initialize AWS clients
const dynamodb = new AWS.DynamoDB.DocumentClient();
const eventbridge = new AWS.EventBridge();

/**
 * API Ingest Handler - Processes HTTP API requests and publishes events
 */
module.exports.processApiRequest = async (event, context) => {
  console.log('API Ingest - Event:', JSON.stringify(event, null, 2));

  try {
    // Extract HTTP method and path
    const { httpMethod, path, body, headers } = event;
    const requestBody = body ? JSON.parse(body) : {};

    // Generate a user ID for demo purposes
    const userId = requestBody.userId || `user-${Date.now()}`;
    const timestamp = Date.now();

    // Create user record
    const userRecord = {
      userId,
      createdAt: timestamp,
      updatedAt: timestamp,
      ...requestBody,
      status: 'active'
    };

    // Save to DynamoDB
    await dynamodb.put({
      TableName: process.env.TABLE_NAME || 'users',
      Item: userRecord
    }).promise();

    // Publish user.created event
    await eventbridge.putEvents({
      Entries: [{
        Source: 'user.service',
        DetailType: 'user.created',
        Detail: JSON.stringify({
          userId,
          ...userRecord
        }),
        EventBusName: 'user-events'
      }]
    }).promise();

    return {
      statusCode: 201,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST,GET,PUT,DELETE'
      },
      body: JSON.stringify({
        message: 'User created successfully',
        user: userRecord
      })
    };

  } catch (error) {
    console.error('Error processing API request:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: 'Internal server error',
        error: error.message
      })
    };
  }
};

/**
 * User Created Processor - Handles user.created events
 */
module.exports.processUserCreated = async (event, context) => {
  console.log('User Created Processor - Event:', JSON.stringify(event, null, 2));

  try {
    // Process EventBridge events
    if (event.Records) {
      for (const record of event.Records) {
        if (record.eventSource === 'aws:events') {
          // EventBridge event
          const detail = JSON.parse(record.body);
          await handleUserCreatedEvent(detail);
        } else if (record.eventSource === 'aws:dynamodb') {
          // DynamoDB Stream event
          await handleDynamoDBStreamEvent(record);
        }
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'User events processed successfully'
      })
    };

  } catch (error) {
    console.error('Error processing user created events:', error);
    throw error;
  }
};

/**
 * User Updated Processor - Handles user.updated events
 */
module.exports.processUserUpdated = async (event, context) => {
  console.log('User Updated Processor - Event:', JSON.stringify(event, null, 2));

  try {
    if (event.Records) {
      for (const record of event.Records) {
        if (record.eventSource === 'aws:events') {
          const detail = JSON.parse(record.body);
          await handleUserUpdatedEvent(detail);
        }
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'User update events processed successfully'
      })
    };

  } catch (error) {
    console.error('Error processing user updated events:', error);
    throw error;
  }
};

/**
 * DLQ Reprocessor - Reprocesses failed events from DLQ
 */
module.exports.reprocessFromDLQ = async (event, context) => {
  console.log('DLQ Reprocessor - Event:', JSON.stringify(event, null, 2));

  try {
    if (event.Records) {
      for (const record of event.Records) {
        // Parse the failed message
        const messageBody = JSON.parse(record.body);
        const originalEvent = JSON.parse(messageBody.Message);

        console.log('Reprocessing event:', originalEvent);

        // Logic to reprocess the event would go here
        // For now, just log that we're reprocessing
        console.log(`Reprocessing event for ${originalEvent.detailType}`);
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'DLQ reprocessing completed'
      })
    };

  } catch (error) {
    console.error('Error reprocessing from DLQ:', error);
    throw error;
  }
};

/**
 * Helper function to handle user.created events
 */
async function handleUserCreatedEvent(detail) {
  console.log(`Processing user.created event for user: ${detail.userId}`);

  // Example: Send welcome notification
  console.log('Sending welcome notification for user:', detail.userId);

  // Example: Create user analytics record
  console.log('Creating analytics record for user:', detail.userId);
}

/**
 * Helper function to handle user.updated events
 */
async function handleUserUpdatedEvent(detail) {
  console.log(`Processing user.updated event for user: ${detail.userId}`);

  // Example: Update analytics
  console.log('Updating analytics for user:', detail.userId);
}

/**
 * Helper function to handle DynamoDB stream events
 */
async function handleDynamoDBStreamEvent(record) {
  const eventName = record.eventName;
  const newImage = record.dynamodb.NewImage;
  const oldImage = record.dynamodb.OldImage;

  console.log(`Processing DynamoDB stream event: ${eventName}`);

  if (eventName === 'INSERT') {
    console.log('New user created:', AWS.DynamoDB.Converter.unmarshall(newImage));
  } else if (eventName === 'MODIFY') {
    console.log('User updated:', AWS.DynamoDB.Converter.unmarshall(newImage));
  } else if (eventName === 'REMOVE') {
    console.log('User deleted:', AWS.DynamoDB.Converter.unmarshall(oldImage));
  }
}