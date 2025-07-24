import ComposableArchitecture
import Foundation

// MARK: - SLA Template Service

public struct SLATemplateService: Sendable {
    public var loadTemplate: @Sendable (SLAIndustry) async throws -> SLATemplate
    public var customizeTemplate: @Sendable (SLATemplate, SLACustomization) async throws -> String
    public var validateSLA: @Sendable (String) async throws -> SLAValidation
    public var generateMetrics: @Sendable (SLAIndustry) async throws -> [SLAMetric]

    public init(
        loadTemplate: @escaping @Sendable (SLAIndustry) async throws -> SLATemplate,
        customizeTemplate: @escaping @Sendable (SLATemplate, SLACustomization) async throws -> String,
        validateSLA: @escaping @Sendable (String) async throws -> SLAValidation,
        generateMetrics: @escaping @Sendable (SLAIndustry) async throws -> [SLAMetric]
    ) {
        self.loadTemplate = loadTemplate
        self.customizeTemplate = customizeTemplate
        self.validateSLA = validateSLA
        self.generateMetrics = generateMetrics
    }
}

// MARK: - SLA Models

public enum SLAIndustry: String, CaseIterable, Sendable {
    case telecommunications = "Telecommunications"
    case cloudComputing = "Cloud Computing"
    case dataCenter = "Data Center"
    case cybersecurity = "Cybersecurity"
    case logistics = "Logistics"
    case itSupport = "IT Support"
    case softwareDevelopment = "Software Development"
    case networkServices = "Network Services"
    case satelliteCommunications = "Satellite Communications"
    case managedServices = "Managed Services"
}

public struct SLATemplate: Sendable {
    public let industry: SLAIndustry
    public let name: String
    public let description: String
    public let sections: [SLASection]
    public let metrics: [SLAMetric]
    public let penalties: [SLAPenalty]

    public init(
        industry: SLAIndustry,
        name: String,
        description: String,
        sections: [SLASection],
        metrics: [SLAMetric],
        penalties: [SLAPenalty]
    ) {
        self.industry = industry
        self.name = name
        self.description = description
        self.sections = sections
        self.metrics = metrics
        self.penalties = penalties
    }
}

public struct SLASection: Sendable {
    public let title: String
    public let content: String
    public let isRequired: Bool

    public init(title: String, content: String, isRequired: Bool = true) {
        self.title = title
        self.content = content
        self.isRequired = isRequired
    }
}

public struct SLAMetric: Sendable {
    public let name: String
    public let description: String
    public let measurementMethod: String
    public let target: String
    public let criticalThreshold: String?

    public init(
        name: String,
        description: String,
        measurementMethod: String,
        target: String,
        criticalThreshold: String? = nil
    ) {
        self.name = name
        self.description = description
        self.measurementMethod = measurementMethod
        self.target = target
        self.criticalThreshold = criticalThreshold
    }
}

public struct SLAPenalty: Sendable {
    public let metric: String
    public let threshold: String
    public let penalty: String

    public init(metric: String, threshold: String, penalty: String) {
        self.metric = metric
        self.threshold = threshold
        self.penalty = penalty
    }
}

public struct SLACustomization: Sendable {
    public let availabilityTarget: Double
    public let maintenanceWindow: String
    public let responseTimeRequirements: [String: String]
    public let customMetrics: [SLAMetric]
    public let excludedSections: Set<String>

    public init(
        availabilityTarget: Double = 99.9,
        maintenanceWindow: String = "Sunday 2-6 AM EST",
        responseTimeRequirements: [String: String] = [:],
        customMetrics: [SLAMetric] = [],
        excludedSections: Set<String> = []
    ) {
        self.availabilityTarget = availabilityTarget
        self.maintenanceWindow = maintenanceWindow
        self.responseTimeRequirements = responseTimeRequirements
        self.customMetrics = customMetrics
        self.excludedSections = excludedSections
    }
}

public struct SLAValidation: Sendable {
    public let isValid: Bool
    public let issues: [String]
    public let suggestions: [String]

    public init(isValid: Bool, issues: [String], suggestions: [String]) {
        self.isValid = isValid
        self.issues = issues
        self.suggestions = suggestions
    }
}

// MARK: - Live Value

extension SLATemplateService: DependencyKey {
    public static var liveValue: SLATemplateService {
        SLATemplateService(
            loadTemplate: { industry in
                let telecommunicationsSLATemplate = SLATemplate(
                    industry: .telecommunications,
                    name: "Telecommunications Service Level Agreement",
                    description: "Comprehensive SLA for telecom services including voice, data, and network",
                    sections: [
                        SLASection(
                            title: "Service Availability",
                            content: """
                            The Service Provider guarantees {{AVAILABILITY}} network availability measured on a monthly basis.

                            Availability = (Total Minutes - Downtime Minutes) / Total Minutes × 100

                            Exclusions:
                            - Scheduled maintenance during agreed windows
                            - Force majeure events
                            - Customer premises equipment failures

                            Measurement:
                            - Calculated monthly from first to last day
                            - Reported within 5 business days of month end
                            """
                        ),
                        SLASection(
                            title: "Response Times",
                            content: """
                            Service Provider will respond to service requests as follows:

                            Priority 1 (Critical): {{P1_RESPONSE}} minutes
                            Priority 2 (High): {{P2_RESPONSE}} hours  
                            Priority 3 (Medium): {{P3_RESPONSE}} hours
                            Priority 4 (Low): {{P4_RESPONSE}} business days

                            Response time measured from ticket creation to first technician contact.
                            """
                        ),
                        SLASection(
                            title: "Resolution Times",
                            content: """
                            Target resolution times by priority:

                            Priority 1: {{P1_RESOLUTION}} hours
                            Priority 2: {{P2_RESOLUTION}} hours
                            Priority 3: {{P3_RESOLUTION}} business days
                            Priority 4: {{P4_RESOLUTION}} business days

                            Resolution time measured from initial response to service restoration.
                            """
                        ),
                        SLASection(
                            title: "Performance Metrics",
                            content: """
                            Network Performance Standards:
                            - Latency: < {{MAX_LATENCY}}ms
                            - Packet Loss: < {{MAX_PACKET_LOSS}}%
                            - Jitter: < {{MAX_JITTER}}ms
                            - Throughput: ≥ {{MIN_THROUGHPUT}}% of contracted bandwidth

                            Voice Quality (if applicable):
                            - Mean Opinion Score (MOS): ≥ {{MIN_MOS}}
                            - Post Dial Delay: < {{MAX_PDD}}ms
                            """
                        )
                    ],
                    metrics: [],
                    penalties: []
                )
                
                switch industry {
                case .telecommunications:
                    return telecommunicationsSLATemplate
                case .cloudComputing:
                    return cloudComputingSLATemplate
                case .dataCenter:
                    return dataCenterSLATemplate
                case .cybersecurity:
                    return cybersecuritySLATemplate
                case .logistics:
                    return logisticsSLATemplate
                case .itSupport:
                    return itSupportSLATemplate
                case .softwareDevelopment:
                    return softwareDevelopmentSLATemplate
                case .networkServices:
                    return networkServicesSLATemplate
                case .satelliteCommunications:
                    return satelliteCommunicationsSLATemplate
                case .managedServices:
                    return managedServicesSLATemplate
                }
            },

            customizeTemplate: { template, customization in
                var content = """
                SERVICE LEVEL AGREEMENT
                \(template.name)

                """

                // Add sections
                for section in template.sections where !customization.excludedSections.contains(section.title) {
                    content += """
                    \(section.title.uppercased())

                    \(section.content)

                    """
                }

                // Add custom metrics
                if !customization.customMetrics.isEmpty {
                    content += """
                    ADDITIONAL PERFORMANCE METRICS

                    """
                    for metric in customization.customMetrics {
                        content += "• \(metric.name): \(metric.target)\n"
                    }
                    content += "\n"
                }

                // Apply customizations
                content = content.replacingOccurrences(of: "{{AVAILABILITY}}", with: "\(customization.availabilityTarget)%")
                content = content.replacingOccurrences(of: "{{MAINTENANCE_WINDOW}}", with: customization.maintenanceWindow)

                for (key, value) in customization.responseTimeRequirements {
                    content = content.replacingOccurrences(of: "{{\(key)}}", with: value)
                }

                return content
            },

            validateSLA: { slaContent in
                var issues: [String] = []
                var suggestions: [String] = []

                // Check for required elements
                if !slaContent.contains("availability"), !slaContent.contains("uptime") {
                    issues.append("Missing availability/uptime requirements")
                    suggestions.append("Add specific availability percentage (e.g., 99.9%)")
                }

                if !slaContent.contains("maintenance") {
                    issues.append("Missing maintenance window definition")
                    suggestions.append("Define scheduled maintenance windows")
                }

                if !slaContent.contains("response time"), !slaContent.contains("latency") {
                    issues.append("Missing response time requirements")
                    suggestions.append("Add response time metrics and thresholds")
                }

                if !slaContent.contains("remedy"), !slaContent.contains("credit"), !slaContent.contains("penalty") {
                    issues.append("Missing remedies for SLA violations")
                    suggestions.append("Define service credits or penalties for non-compliance")
                }

                if !slaContent.contains("report") {
                    issues.append("Missing reporting requirements")
                    suggestions.append("Specify SLA reporting frequency and format")
                }

                return SLAValidation(
                    isValid: issues.isEmpty,
                    issues: issues,
                    suggestions: suggestions
                )
            },

            generateMetrics: { industry in
                // Return industry-specific metrics
                switch industry {
                case .telecommunications:
                    [
                        SLAMetric(
                            name: "Network Availability",
                            description: "Percentage of time network is operational",
                            measurementMethod: "Automated monitoring tools",
                            target: "99.99%",
                            criticalThreshold: "99.9%"
                        ),
                        SLAMetric(
                            name: "Mean Time to Repair (MTTR)",
                            description: "Average time to restore service after outage",
                            measurementMethod: "Incident tracking system",
                            target: "< 4 hours",
                            criticalThreshold: "8 hours"
                        ),
                        SLAMetric(
                            name: "Packet Loss",
                            description: "Percentage of data packets lost in transmission",
                            measurementMethod: "Network monitoring",
                            target: "< 0.1%",
                            criticalThreshold: "1%"
                        ),
                        SLAMetric(
                            name: "Latency",
                            description: "Round-trip delay for data transmission",
                            measurementMethod: "Ping tests from multiple locations",
                            target: "< 50ms",
                            criticalThreshold: "100ms"
                        ),
                        SLAMetric(
                            name: "Jitter",
                            description: "Variation in packet arrival times",
                            measurementMethod: "Real-time monitoring",
                            target: "< 5ms",
                            criticalThreshold: "20ms"
                        ),
                    ]

                case .cloudComputing:
                    [
                        SLAMetric(
                            name: "Service Availability",
                            description: "Uptime for cloud services",
                            measurementMethod: "Service health monitoring",
                            target: "99.95%",
                            criticalThreshold: "99.9%"
                        ),
                        SLAMetric(
                            name: "API Response Time",
                            description: "Time to process API requests",
                            measurementMethod: "API monitoring",
                            target: "< 200ms",
                            criticalThreshold: "500ms"
                        ),
                        SLAMetric(
                            name: "Storage Durability",
                            description: "Data integrity and persistence",
                            measurementMethod: "Checksum verification",
                            target: "99.999999999%",
                            criticalThreshold: "99.99999%"
                        ),
                        SLAMetric(
                            name: "Auto-scaling Response",
                            description: "Time to scale resources",
                            measurementMethod: "Performance monitoring",
                            target: "< 2 minutes",
                            criticalThreshold: "5 minutes"
                        ),
                    ]

                default:
                    [
                        SLAMetric(
                            name: "Service Availability",
                            description: "Overall service uptime",
                            measurementMethod: "Monitoring tools",
                            target: "99.9%",
                            criticalThreshold: "99.5%"
                        ),
                        SLAMetric(
                            name: "Response Time",
                            description: "Time to respond to requests",
                            measurementMethod: "Performance monitoring",
                            target: "Varies by service",
                            criticalThreshold: "2x target"
                        ),
                    ]
                }
            }
        )
    }
}

// MARK: - Industry-Specific Templates

private let telecommunicationsSLATemplate = SLATemplate(
    industry: .telecommunications,
    name: "Telecommunications Service Level Agreement",
    description: "Comprehensive SLA for telecom services including voice, data, and network",
    sections: [
        SLASection(
            title: "Service Availability",
            content: """
            The Service Provider guarantees {{AVAILABILITY}} network availability measured on a monthly basis.

            Availability = (Total Minutes - Downtime Minutes) / Total Minutes × 100

            Exclusions:
            - Scheduled maintenance during agreed windows
            - Force majeure events
            - Customer-caused outages
            """
        ),
        SLASection(
            title: "Network Performance",
            content: """
            Performance Metrics:
            - Latency: Maximum {{LATENCY}} round-trip time
            - Packet Loss: Less than {{PACKET_LOSS}}
            - Jitter: Maximum {{JITTER}}
            - Bandwidth: Guaranteed {{BANDWIDTH}} throughput
            """
        ),
        SLASection(
            title: "Maintenance Windows",
            content: """
            Scheduled Maintenance: {{MAINTENANCE_WINDOW}}
            Emergency Maintenance: 24-hour advance notice when possible
            Maximum Duration: 4 hours per maintenance window
            """
        ),
        SLASection(
            title: "Service Credits",
            content: """
            Monthly Availability | Service Credit
            99.9% - 99.99%      | 0%
            99.0% - 99.89%      | 5%
            98.0% - 98.99%      | 10%
            97.0% - 97.99%      | 20%
            Below 97.0%         | 30%
            """
        ),
    ],
    metrics: [],
    penalties: [
        SLAPenalty(
            metric: "Availability",
            threshold: "< 99.9%",
            penalty: "Service credits per table"
        ),
        SLAPenalty(
            metric: "MTTR",
            threshold: "> 4 hours",
            penalty: "5% credit per hour over threshold"
        ),
    ]
)

private let cloudComputingSLATemplate = SLATemplate(
    industry: .cloudComputing,
    name: "Cloud Computing Service Level Agreement",
    description: "SLA for cloud infrastructure, platform, and software services",
    sections: [
        SLASection(
            title: "Service Availability Tiers",
            content: """
            Compute Instances: {{AVAILABILITY}} uptime
            Storage Services: 99.999999999% durability
            Database Services: 99.99% availability
            Network Services: 99.99% availability

            Multi-Region Deployments: 99.995% availability
            """
        ),
        SLASection(
            title: "Performance Guarantees",
            content: """
            API Response Times:
            - GET requests: < 100ms (p95)
            - POST/PUT requests: < 200ms (p95)
            - Large payload operations: < 1000ms (p95)

            Storage Performance:
            - Read IOPS: {{READ_IOPS}}
            - Write IOPS: {{WRITE_IOPS}}
            - Throughput: {{THROUGHPUT}}
            """
        ),
        SLASection(
            title: "Data Protection",
            content: """
            - Automated backups every 24 hours
            - Point-in-time recovery (last 7 days)
            - Geo-redundant storage replication
            - Encryption at rest and in transit
            """
        ),
        SLASection(
            title: "Support Response Times",
            content: """
            Severity 1 (Production Down): 15 minutes
            Severity 2 (Production Impaired): 1 hour
            Severity 3 (Non-Production): 4 hours
            Severity 4 (General Inquiry): 24 hours
            """
        ),
    ],
    metrics: [],
    penalties: []
)

private let dataCenterSLATemplate = SLATemplate(
    industry: .dataCenter,
    name: "Data Center Colocation Service Level Agreement",
    description: "SLA for data center colocation and hosting services",
    sections: [
        SLASection(
            title: "Power Availability",
            content: """
            Power Uptime: {{AVAILABILITY}}
            - Dual power feeds to each rack
            - UPS protection with N+1 redundancy
            - Generator backup with 72-hour fuel capacity
            - Monthly generator testing
            """
        ),
        SLASection(
            title: "Environmental Controls",
            content: """
            Temperature: 65-80°F (18-27°C)
            Humidity: 40-60% RH
            HVAC Redundancy: N+1 configuration
            Hot/Cold aisle containment
            """
        ),
        SLASection(
            title: "Physical Security",
            content: """
            - 24/7/365 on-site security personnel
            - Biometric access controls
            - CCTV monitoring and recording
            - Mantrap entry systems
            - Visitor escort requirements
            """
        ),
        SLASection(
            title: "Network Connectivity",
            content: """
            - Carrier-neutral facility
            - Diverse fiber entry points
            - Meet-me room access
            - Cross-connect completion: 24 hours
            """
        ),
    ],
    metrics: [],
    penalties: []
)

private let cybersecuritySLATemplate = SLATemplate(
    industry: .cybersecurity,
    name: "Cybersecurity Services Level Agreement",
    description: "SLA for managed security services and incident response",
    sections: [
        SLASection(
            title: "Threat Detection and Response",
            content: """
            Detection Time:
            - Critical threats: < 5 minutes
            - High severity: < 15 minutes
            - Medium severity: < 30 minutes
            - Low severity: < 60 minutes

            Response Time:
            - Critical: Immediate escalation
            - High: 15-minute response
            - Medium: 1-hour response
            - Low: 4-hour response
            """
        ),
        SLASection(
            title: "Security Operations Center (SOC)",
            content: """
            - 24/7/365 SOC operations
            - Real-time threat monitoring
            - Certified security analysts
            - Tier 1-3 support structure
            - Monthly threat briefings
            """
        ),
        SLASection(
            title: "Incident Management",
            content: """
            - Incident containment: < 2 hours
            - Forensic analysis initiation: < 4 hours
            - Preliminary report: < 24 hours
            - Full incident report: < 72 hours
            - Remediation support included
            """
        ),
        SLASection(
            title: "Vulnerability Management",
            content: """
            Scanning Frequency:
            - External scans: Weekly
            - Internal scans: Monthly
            - Critical asset scans: Daily

            Reporting:
            - Critical vulnerabilities: Immediate
            - High/Medium: Within 24 hours
            - Remediation tracking provided
            """
        ),
    ],
    metrics: [],
    penalties: []
)

private let logisticsSLATemplate = SLATemplate(
    industry: .logistics,
    name: "Logistics and Supply Chain Service Level Agreement",
    description: "SLA for logistics, warehousing, and distribution services",
    sections: [
        SLASection(
            title: "Order Fulfillment",
            content: """
            Order Processing:
            - Same-day processing: Orders by 2 PM
            - Order accuracy: {{ORDER_ACCURACY}}%
            - Inventory accuracy: 99.8%

            Shipping Times:
            - Standard: 3-5 business days
            - Expedited: 1-2 business days
            - Express: Next business day
            """
        ),
        SLASection(
            title: "Warehouse Operations",
            content: """
            - Receiving: Same-day processing
            - Put-away: Within 24 hours
            - Cycle counting: Weekly
            - Physical inventory: Quarterly
            - Temperature control: ±2°F variance
            """
        ),
        SLASection(
            title: "Transportation",
            content: """
            On-Time Delivery: {{ON_TIME_DELIVERY}}%
            - GPS tracking on all shipments
            - Real-time status updates
            - Proof of delivery within 2 hours
            - Claims processing: 48 hours
            """
        ),
        SLASection(
            title: "Returns Processing",
            content: """
            - Return authorization: Same day
            - Inspection: Within 48 hours
            - Credit processing: 5 business days
            - Restocking: Within 72 hours
            """
        ),
    ],
    metrics: [],
    penalties: []
)

private let itSupportSLATemplate = SLATemplate(
    industry: .itSupport,
    name: "IT Support Services Level Agreement",
    description: "SLA for help desk and technical support services",
    sections: [
        SLASection(
            title: "Support Availability",
            content: """
            Help Desk Hours: {{SUPPORT_HOURS}}
            - Phone support: 24/7/365
            - Email support: 24-hour response
            - Chat support: Business hours
            - On-site support: By appointment
            """
        ),
        SLASection(
            title: "Response Time Commitments",
            content: """
            Priority 1 (System Down): 15 minutes
            Priority 2 (Major Impact): 1 hour
            Priority 3 (Minor Impact): 4 hours
            Priority 4 (Information): 24 hours
            """
        ),
        SLASection(
            title: "Resolution Targets",
            content: """
            Priority 1: 4 hours
            Priority 2: 8 hours
            Priority 3: 24 hours
            Priority 4: 72 hours

            First-call resolution rate: > 70%
            """
        ),
        SLASection(
            title: "Service Desk Metrics",
            content: """
            - Average wait time: < 2 minutes
            - Call abandonment rate: < 5%
            - Customer satisfaction: > 90%
            - Ticket backlog: < 5% of monthly volume
            """
        ),
    ],
    metrics: [],
    penalties: []
)

private let softwareDevelopmentSLATemplate = SLATemplate(
    industry: .softwareDevelopment,
    name: "Software Development Service Level Agreement",
    description: "SLA for custom software development and maintenance",
    sections: [
        SLASection(
            title: "Development Standards",
            content: """
            Code Quality:
            - Code coverage: Minimum 80%
            - Security scanning: Every build
            - Code review: 100% of changes
            - Documentation: Complete API docs
            """
        ),
        SLASection(
            title: "Delivery Commitments",
            content: """
            Sprint Deliverables:
            - Sprint planning: First day
            - Daily standups: Every business day
            - Sprint demo: Last day
            - Velocity target: {{VELOCITY}} story points
            """
        ),
        SLASection(
            title: "Bug Fix Response Times",
            content: """
            Critical (Production Down): 2 hours
            High (Major Feature): 24 hours
            Medium (Minor Feature): 72 hours
            Low (Cosmetic): Next release
            """
        ),
        SLASection(
            title: "Maintenance and Support",
            content: """
            - Security patches: Within 24 hours
            - Version updates: Monthly
            - Technical debt: 20% of capacity
            - Knowledge transfer: Quarterly
            """
        ),
    ],
    metrics: [],
    penalties: []
)

private let networkServicesSLATemplate = SLATemplate(
    industry: .networkServices,
    name: "Network Services Level Agreement",
    description: "SLA for managed network and connectivity services",
    sections: [
        SLASection(
            title: "Network Availability",
            content: """
            Core Network: {{AVAILABILITY}}
            - Redundant paths required
            - Automatic failover: < 50ms
            - BGP convergence: < 30 seconds
            - MPLS availability: 99.99%
            """
        ),
        SLASection(
            title: "Circuit Performance",
            content: """
            Committed Information Rate (CIR): 100% guaranteed
            Burst capability: Up to 150% of CIR
            Frame loss: < 0.1%
            Out-of-order delivery: < 0.01%
            """
        ),
        SLASection(
            title: "Network Management",
            content: """
            - 24/7 NOC monitoring
            - Proactive notification: 15 minutes
            - Configuration changes: 48-hour notice
            - Emergency changes: 1-hour approval
            """
        ),
        SLASection(
            title: "Quality of Service",
            content: """
            Traffic Classes:
            - Real-time (EF): Highest priority
            - Business Critical (AF4): High priority
            - Standard Business (AF3): Medium priority
            - Best Effort (BE): Standard delivery
            """
        ),
    ],
    metrics: [],
    penalties: []
)

private let satelliteCommunicationsSLATemplate = SLATemplate(
    industry: .satelliteCommunications,
    name: "Satellite Communications Service Level Agreement",
    description: "SLA for satellite connectivity and communication services",
    sections: [
        SLASection(
            title: "Service Availability",
            content: """
            Satellite Link Availability: {{AVAILABILITY}}
            - Weather-related outages excluded
            - Sun outage predictions provided
            - Redundant transponders available
            """
        ),
        SLASection(
            title: "Link Performance",
            content: """
            Signal Quality:
            - Bit Error Rate: < 10^-7
            - Eb/No margin: > 3 dB
            - Rain fade margin: Location-specific

            Throughput:
            - Committed rate: 100% CIR
            - Burst capability: Per service plan
            """
        ),
        SLASection(
            title: "Orbital and Coverage",
            content: """
            - Coverage area: As per footprint map
            - Elevation angle: Minimum 10 degrees
            - Look angle calculator provided
            - Orbital position maintained ±0.05°
            """
        ),
        SLASection(
            title: "Ground Segment Support",
            content: """
            - Teleport availability: 99.99%
            - Hub redundancy: Full 1:1
            - Remote terminal support: 24/7
            - Spare equipment: 4-hour delivery
            """
        ),
    ],
    metrics: [],
    penalties: []
)

private let managedServicesSLATemplate = SLATemplate(
    industry: .managedServices,
    name: "Managed Services Level Agreement",
    description: "SLA for comprehensive IT managed services",
    sections: [
        SLASection(
            title: "Service Catalog",
            content: """
            Infrastructure Management:
            - Server monitoring: 24/7
            - Patch management: Monthly
            - Backup verification: Daily
            - Capacity planning: Quarterly
            """
        ),
        SLASection(
            title: "Proactive Maintenance",
            content: """
            - System health checks: Weekly
            - Performance optimization: Monthly
            - Security assessments: Quarterly
            - Documentation updates: Ongoing
            """
        ),
        SLASection(
            title: "Service Desk",
            content: """
            Multi-channel support:
            - Phone: {{PHONE_AVAILABILITY}}
            - Email: 1-hour response
            - Portal: Self-service 24/7
            - Remote access: As needed
            """
        ),
        SLASection(
            title: "Reporting and Reviews",
            content: """
            - Real-time dashboards
            - Monthly service reports
            - Quarterly business reviews
            - Annual strategic planning
            - SLA performance metrics
            """
        ),
    ],
    metrics: [],
    penalties: []
)

// MARK: - Test Value

public extension SLATemplateService {
    static var testValue: SLATemplateService {
        SLATemplateService(
            loadTemplate: { _ in
                SLATemplate(
                    industry: .telecommunications,
                    name: "Test SLA",
                    description: "Test template",
                    sections: [
                        SLASection(title: "Test Section", content: "Test content"),
                    ],
                    metrics: [],
                    penalties: []
                )
            },
            customizeTemplate: { _, _ in "Customized test SLA" },
            validateSLA: { _ in SLAValidation(isValid: true, issues: [], suggestions: []) },
            generateMetrics: { _ in [] }
        )
    }
}

// MARK: - Dependency Registration

public extension DependencyValues {
    var slaTemplateService: SLATemplateService {
        get { self[SLATemplateService.self] }
        set { self[SLATemplateService.self] = newValue }
    }
}
