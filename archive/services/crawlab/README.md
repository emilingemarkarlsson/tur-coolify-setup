# Crawlab Scraping Management Platform

Professional web scraping management platform for The Hockey Analytics.

## Deployment
- Domain: `scrapers.thehockeyanalytics.com`
- Default login: `admin` / `admin` (change after first login)
- MongoDB: Included with authentication
- Redis: Included with password protection

## Features
- Visual spider management interface
- Distributed scraping with multiple nodes
- Real-time monitoring and logging
- Scheduled scraping tasks
- Data export capabilities
- Performance analytics

## Architecture
- **Crawlab**: Main scraping platform (port 8080)
- **MongoDB**: Data storage for spider configurations
- **Redis**: Task queue and caching

## Use Cases for THA
- **NHL API Scraping**: Teams, players, games, statistics
- **ESPN Data Collection**: Hockey news and analytics
- **SHL Integration**: Swedish hockey league data
- **IIHF Data**: International tournament results
- **Custom Scrapers**: Any hockey-related websites

## Environment Variables
```
CRAWLAB_MONGO_HOST=mongo
CRAWLAB_REDIS_ADDRESS=redis
MONGO_INITDB_ROOT_USERNAME=crawlab_admin
MONGO_INITDB_ROOT_PASSWORD=secure_mongo_crawlab_2025
```

## Integration with THA Infrastructure
- **MinIO**: Raw scraped data storage
- **Mage AI**: ETL pipeline triggers via webhooks
- **N8N**: Automation workflows and scheduling
- **ClickHouse**: Final processed data destination

## Deploy
Use the provided `docker-compose.yml` in Coolify. This includes:
- Crawlab main application
- MongoDB database
- Redis cache
- Persistent volumes for all data