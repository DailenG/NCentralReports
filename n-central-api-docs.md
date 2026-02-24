# Getting Started with N-central APIs

Welcome to N-central's API documentation! This guide will help you quickly integrate N-central's powerful features into your workflows. Whether you're a developer building custom integrations or an IT professional automating your operations, we'll guide you through each step of working with our APIs.

***Tip:** Use the [Search function](https://n-able.wistia.com/medias/80pvj7ughm) to discover all the powerful capabilities of the Developer Portal.*

## What You Can Achieve with N-central APIs

N-central's REST APIs offer powerful capabilities across multiple domains to enhance your operations:

### Authentication & System Health

* Secure token-based authentication management
* System health monitoring and status checks
* Version tracking and system information retrieval
* Service availability verification

### Organization Management

* Create and manage service organizations
* Handle customer lifecycle and relationships
* Organize sites under customers
* Maintain organizational hierarchy
* Track organizational unit details and metadata

### Device Management

* Monitor device health and status
* Track device assets and lifecycle information
* Manage device maintenance windows
* Configure service monitoring
* Access detailed device metrics and performance data

### User & Access Control

* Manage user accounts and permissions
* Configure access groups for devices and organizations
* Define and assign user roles
* Control authentication and authorization
* Handle user provisioning and access rights

### Task & Job Management

* Schedule and manage automated tasks
* Monitor task execution status
* Track job progress and completion
* Configure direct support tasks
* Manage task scheduling and timing

### PSA Integration

* Connect with Professional Services Automation systems
* Manage PSA credentials and authentication
* Handle ticket creation and updates
* Track PSA integration status

### Custom Properties & Configuration

* Define custom properties for organizations
* Configure device-specific properties
* Set default property values
* Manage property inheritance and propagation

### Device Filters & Registration

* Create and manage device filters
* Handle device registration tokens
* Configure registration settings
* Control device onboarding process

### Active Issue Management

* Monitor active issues across organizations
* Track issue status and resolution
* Manage issue notifications
* Handle issue prioritization

## Before You Start

### Requirements

1. **N-central Environment**
   * N-central instance (version 2023.9 or later)
   * Valid [user account](create-an-api-only-user) with appropriate permissions
   * Access to N-central's administration interface

2. **Authentication Prerequisites**
   * JWT (JSON Web Token) for initial authentication
   * Understanding of bearer token authentication
   * Access to generate API tokens from N-central UI

3. **Technical Requirements**
   * Basic understanding of REST APIs
   * Familiarity with HTTP requests
   * Knowledge of JSON data structures

## Authentication Guide

To use N-central's APIs, you'll need to follow this authentication flow:

1. **Generate JWT Token**
   * Navigate to Administration → User Management → Users
   * Select your user [API-Only User](create) account
   * Access API Access section
   * Generate JSON Web Token

2. **Obtain Access Token**
   ```http
   POST /api/auth/authenticate
   Authorization: Bearer <YOUR_JWT>
   ```

3. **Use Access Token**
   * Include the access token in all subsequent API requests
   * Use bearer authentication format
   * Token expires after 1 hour by default

## Making Your First API Call

Here's a simple example to get started:

1. **List All Devices**
   ```http
   GET /api/devices
   Authorization: Bearer <YOUR_ACCESS_TOKEN>
   ```

2. **Create a Service Organization**

   ```http
   POST /api/service-orgs
   Authorization: Bearer <YOUR_ACCESS_TOKEN>
   Content-Type: application/json

   {
     "soName": "New SO name",
     "contactFirstName": "John",
     "contactLastName": "Doe",
     "contactEmail": "contact@email.com"
   }
   ```

## Getting Help

Our support team is here to help you succeed with your integration:

* Check our comprehensive [API reference documentation](https://developer.n-able.com/n-central/reference/refresh)
* Contact support for technical assistance
