# Voting App
I selected a straightforward microservices web application that prompts users to vote between a dog and a cat. I opted for this application to reinforce and apply my recently acquired knowledge of Kubernetes and EKS, as it presents microservices architecture in a straightforward manner.

## Components
* The voting app interface, developed in __Python__, utilizes __Redis__ as an in-memory database to store user choices.
* The Worker app, built on __.NET__, retrieves the saved results from Redis and stores them in a __Postgres__ database.
* The Result app interface, developed in __Node.js__, retrieves all results from the Postgres database, performs percentage-based comparisons, and presents the results.

![Components](https://github.com/AhmedElSheriff/Voting-App-Kubernetes/master/architecture.excalidraw.png)

## Implementation
To establish the network environment on AWS, I employed CloudFormation for provisioning and the eksctl tool to create the EKS cluster. Additionally, I deployed two worker nodes on private subnets.

For efficient management, I organized the application deployment files into the following components:
* voting-app.yml: Defines a pod containing a container based on the voting app image, which exposes port 80. It also includes a pod with a container based on the Redis image, exposing port 6379. Additionally, two Cluster IP services are created for each pod.
* worker-app.yml: Consists of a pod with a container based on the worker-app image.
* result-app.yml: Includes a pod with a container based on the result app image, exposing port 80, along with a Cluster IP service associated with it.
* db.yml: Contains a config map and secret with the necessary DB credentials, as well as a PV and PVC for persistent storage of DB files. It also includes a pod with a container based on the Postgres image, exposing port 5432, and a corresponding service.
* ingress.yml: Utilizes the AWS LoadBalancer Controller to create an ALB on AWS, which routes traffic to the vote-app and result-app services based on the hostname.
* A hosted zone on AWS Route 53 that resolves to my custom domain.
* externadns-with-rbac.yml: Comprises the required resources to enable the cluster to use my custom domain hosted on Route 53.

## AWS Infrastructure Diagram
![Infrastructure Diagram](https://github.com/AhmedElSheriff/Voting-App-Kubernetes/master/diagram.png)
