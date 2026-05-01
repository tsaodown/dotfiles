function k8s --description "Kubernetes helper functions"
    set --local ee ""
    set --local cmd ""
    set --local args ""
    
    # Parse arguments
    set --local i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case -ee --ee
                set i (math $i + 1)
                if test $i -gt (count $argv)
                    echo "k8s: -ee requires a value" >&2
                    return 1
                end
                set ee $argv[$i]
            case port-fwd logs events
                set cmd $argv[$i]
                set i (math $i + 1)
                set args $argv[$i..]
                break
            case -h --help
                echo "Usage: k8s -ee <ephemeral-environment> <command> [args...]"
                echo ""
                echo "Commands:"
                echo "  port-fwd <pod partial match> <port number>  Forward port to pod"
                echo "  logs <pod partial match>                    Show pod logs"
                echo "  events <pod partial match>                  Show pod events"
                echo ""
                echo "Options:"
                echo "  -ee, --ee <string>  Ephemeral environment name (required)"
                echo "  -h, --help          Show this help message"
                return 0
            case \*
                echo "k8s: Unknown option or command: \"$argv[$i]\"" >&2
                echo "Run 'k8s --help' for usage information" >&2
                return 1
        end
        set i (math $i + 1)
    end
    
    # Validate required options
    if test -z "$ee"
        echo "k8s: -ee option is required" >&2
        echo "Run 'k8s --help' for usage information" >&2
        return 1
    end
    
    if test -z "$cmd"
        echo "k8s: Command is required" >&2
        echo "Run 'k8s --help' for usage information" >&2
        return 1
    end
    
    # Construct namespace
    set --local NAMESPACE "provider-connections-$ee"
    
    # Validate command-specific arguments
    switch "$cmd"
        case port-fwd
            if test (count $args) -lt 2
                echo "k8s: port-fwd requires <pod partial match> and <port number>" >&2
                return 1
            end
            set --local pod_match $args[1]
            set --local port $args[2]
            
            # Find pod
            set --local pod (kubectl get pods -n $NAMESPACE --no-headers | grep ".*$pod_match.*" | awk '{print $1}' | head -n 1)
            
            if test -z "$pod"
                echo "k8s: No pod found matching \"$pod_match\" in namespace \"$NAMESPACE\"" >&2
                return 1
            end
            
            kubectl -n $NAMESPACE port-forward $pod $port
            
        case logs
            if test (count $args) -lt 1
                echo "k8s: logs requires <pod partial match>" >&2
                return 1
            end
            set --local pod_match $args[1]
            
            # Find pod
            set --local pod (kubectl get pods -n $NAMESPACE --no-headers | grep ".*$pod_match.*" | awk '{print $1}' | head -n 1)
            
            if test -z "$pod"
                echo "k8s: No pod found matching \"$pod_match\" in namespace \"$NAMESPACE\"" >&2
                return 1
            end
            
            kubectl -n $NAMESPACE logs $pod -f
            
        case events
            if test (count $args) -lt 1
                echo "k8s: events requires <pod partial match>" >&2
                return 1
            end
            set --local pod_match $args[1]
            
            # Find pod
            set --local pod (kubectl get pods -n $NAMESPACE --no-headers | grep ".*$pod_match.*" | awk '{print $1}' | head -n 1)
            
            if test -z "$pod"
                echo "k8s: No pod found matching \"$pod_match\" in namespace \"$NAMESPACE\"" >&2
                return 1
            end
            
            kubectl -n $NAMESPACE events $pod
            
        case \*
            echo "k8s: Unknown command: \"$cmd\"" >&2
            echo "Run 'k8s --help' for usage information" >&2
            return 1
    end
end

