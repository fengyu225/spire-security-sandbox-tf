FROM golang:1.23-alpine as builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o spire-aws-auth-plugin .

FROM alpine:latest
WORKDIR /bin
COPY --from=builder /app/spire-aws-auth-plugin .
CMD ["/bin/spire-aws-auth-plugin"]