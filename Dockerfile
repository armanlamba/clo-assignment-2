# Use the official Ubuntu 20.04 image as a base
FROM ubuntu:20.04

# Set environment variables to avoid interaction during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update the package list and install dependencies
RUN apt-get update -y && \
    apt-get install -y python3-pip mysql-client && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . .

# Upgrade pip and install dependencies from requirements.txt
RUN pip3 install --upgrade pip && \
    pip3 install -r requirements.txt

# Expose the port your application runs on
EXPOSE 8080

# Set the entry point and command to run your app
ENTRYPOINT ["python3"]
CMD ["app.py"]
