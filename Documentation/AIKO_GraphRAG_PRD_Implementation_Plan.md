# AIKO GraphRAG Product Requirements Document & Implementation Plan
## Consensus-Validated On-Device Regulation Intelligence System

**Document Type**: Product Requirements Document + Implementation Plan  
**Project**: AIKO iOS Application - Phase 5 GraphRAG Enhancement  
**Date**: July 22, 2025  
**Status**: Consensus Validated ✅ (6/7 AI models approved)  
**Approval**: VanillaIce Multi-Model Consensus Engine  

---

## 🎯 Executive Summary

### Vision Statement
Transform AIKO into the world's first truly intelligent offline regulation research tool using on-device GraphRAG technology.

### Strategic Goals
- **Primary**: Enable instant, accurate regulation queries with perfect citations using LFM2-700M-GGUF Q6_K (612MB) model
- **Impact**: Reduce regulation research time from hours to seconds for government contracting officers
- **Differentiator**: First-to-market offline semantic regulation search for government procurement

### Consensus Validation Results ✅
**Technical Feasibility**: HIGH - LFM2 + ObjectBox approach technically sound for iOS  
**User Value Proposition**: HIGH - Compelling for government contracting officers  
**Architecture Decisions**: OPTIMAL - Well-aligned technology choices  
**Implementation Timeline**: REALISTIC - 10 weeks achievable with phased approach  
**Market Differentiation**: SIGNIFICANT - Meaningful competitive advantage  
**Success Probability**: HIGH - Strong likelihood of delivering promised value  

---

## 📱 Product Overview

### What We're Building
An on-device GraphRAG (Graph-Retrieval Augmented Generation) system that enables government contracting officers to instantly search and query 1000+ federal acquisition regulations with semantic understanding, perfect citations, and complete offline capability.

### Core Technology Stack
- **AI Model**: LFM2-700M-GGUF Q6_K (612MB, optimized for iOS Core ML)
- **Vector Database**: ObjectBox Semantic Index (~100MB for 1000+ regulations)
- **Processing Pipeline**: HTML → regulationParser.ts → Text Chunks → LFM2 Embeddings → Vector Storage → Semantic Search
- **Integration**: iOS Core ML, Swift concurrency, TCA architecture
- **Synchronization**: GitHub API for official GSA repositories, OAuth for personal repos

### Key Capabilities
1. **Semantic Search**: Find regulations by meaning, not just keywords
2. **Instant Results**: Sub-second query responses with 90%+ accuracy
3. **Offline Operation**: Complete functionality without internet after initial setup
4. **Auto-Updates**: Background synchronization with latest regulations
5. **Personal Repositories**: Support for organization-specific regulations
6. **LLM Integration**: Feed search results to existing chat interface for intelligent analysis

---

## 👥 User Stories & Use Cases

### Primary Use Cases

#### 1. Instant Regulation Research
**User**: Senior Contracting Officer  
**Scenario**: "What regulations apply to software procurement over $500K?"  
**Experience**: Types query → Gets sub-second response with exact FAR/DFARS citations → Reviews relevant sections → Makes informed procurement decision  
**Value**: Reduces research time from 45 minutes to 30 seconds  

#### 2. Offline Capability During Travel
**User**: Field Contracting Officer  
**Scenario**: Working on remote military base with limited internet  
**Experience**: Performs complex regulation searches completely offline → Gets same quality results as online → Maintains productivity in any environment  
**Value**: Ensures continuous access to critical regulation information  

#### 3. Always-Current Information
**User**: Compliance Officer  
**Scenario**: Regulations updated overnight by GSA  
**Experience**: App automatically downloads and processes updates → User always works with latest regulations → No manual update management required  
**Value**: Eliminates risk of working with outdated regulation information  

#### 4. Organization-Specific Regulations
**User**: Defense Contract Management Agency Officer  
**Scenario**: Needs to search both standard FAR and agency-specific regulations  
**Experience**: Connects personal GitHub repository → App processes custom regulations → Unified search across official and agency-specific content  
**Value**: Single search interface for all relevant regulations  

#### 5. Intelligent Analysis Integration
**User**: Contract Specialist  
**Scenario**: Found relevant regulations, needs expert analysis  
**Experience**: Search results automatically feed into LLM chat → Gets intelligent interpretation and recommendations → Receives actionable guidance  
**Value**: Combines regulation discovery with expert-level analysis  

---

## 🔧 Technical Requirements

### Model Specifications
- **Primary Model**: LFM2-700M-GGUF Q6_K variant
- **File Size**: 612MB (optimal quality/size balance for iOS)
- **Source**: HuggingFace LiquidAI/LFM2-700M-GGUF (official repository)
- **Format**: Core ML model (.mlmodel) embedded in app bundle
- **Purpose**: On-device embedding generation for regulation text chunks

### Database Architecture
- **Primary**: ObjectBox Semantic Index with vector similarity search
- **Storage**: ~100MB for 1000+ regulations (vector embeddings + metadata)
- **Namespaces**: Separate storage for official vs personal regulations
- **Operations**: Cosine similarity search, incremental updates, metadata filtering
- **Backup**: iOS file system encryption + Keychain credential storage

### Processing Pipeline
```
📄 HTML Regulations (GSA Repository)
    ↓ (regulationParser.ts)
📝 Clean Text Chunks (512 tokens max, semantic boundaries)
    ↓ (LFM2-700M Core ML Model)
🔢 Vector Embeddings (768 dimensions)
    ↓ (ObjectBox Semantic Index)
💾 Searchable Vector Database
    ↓ (User Query + Vector Search)
🔍 Ranked Results (cosine similarity > 0.7)
    ↓ (Integration Layer)
✨ LLM Chat Context + Citations
```

### Integration Requirements
- **iOS Architecture**: Swift 6, SwiftUI, The Composable Architecture (TCA)
- **Concurrency**: Swift actors for thread-safe processing
- **Core ML**: Model loading, inference optimization, memory management
- **Background Processing**: iOS Background App Refresh for auto-updates
- **GitHub API**: Repository access, file comparison, OAuth authentication

---

## ⚡ Performance Requirements

### Response Time Targets
- **Search Latency**: < 1 second for typical regulation queries
- **Embedding Generation**: < 2 seconds per regulation chunk (512 tokens)
- **Model Loading**: < 3 seconds on app startup
- **Auto-Update Processing**: < 5 minutes for daily regulation changes

### Processing Benchmarks
- **Initial Setup**: Complete 1000+ regulations in < 1 hour (one-time)
- **Incremental Updates**: Process 10-50 changed regulations in < 30 seconds
- **Concurrent Processing**: Handle 10 embedding generations simultaneously
- **Memory Efficiency**: Peak < 1GB during processing, < 100MB during search

### Accuracy Standards
- **Search Relevance**: 90%+ relevant results for regulation queries
- **Citation Accuracy**: 95%+ correct regulation number and section references
- **Semantic Understanding**: Successfully match related concepts (e.g., "software procurement" finds "IT acquisition")
- **Update Reliability**: 99.9% successful auto-update completion rate

### Storage Efficiency
- **Model Storage**: 612MB LFM2 model (embedded in app bundle)
- **Vector Database**: ~100MB for complete regulation set
- **Original Content**: ~50MB HTML regulation files (cached locally)
- **Total Footprint**: ~762MB for complete system

---

## 🔒 Security & Privacy Requirements

### Data Privacy Protection
- **On-Device Processing**: All embedding generation and search happens locally
- **Query Privacy**: User search queries never leave the device
- **Content Isolation**: Clear separation between official and personal regulation content
- **Local Storage**: All regulation data and embeddings stored on device only

### Authentication & Access Control
- **GitHub OAuth**: Minimal scopes for personal repository access
- **Credential Storage**: iOS Keychain for secure token storage
- **Repository Validation**: Verify authorized access before processing
- **Access Audit**: Log repository access attempts for security monitoring

### Data Security
- **Encryption**: Vector database encrypted using iOS file system encryption
- **Sandboxing**: iOS app sandbox prevents unauthorized data access
- **Secure Communication**: HTTPS only for GitHub API communications
- **Data Integrity**: Content hashing to verify regulation file integrity

### Compliance Considerations
- **Government Standards**: Align with federal data security requirements
- **Privacy Policy**: Clear disclosure of data collection and processing
- **User Control**: Complete user control over personal repository connections
- **Data Retention**: Local storage only, no cloud data retention

---

## 📅 Implementation Plan (10 Weeks)

### Phase 1: Foundation Setup (Weeks 1-2)
**Goal**: Establish core technical foundation

#### Week 1: LFM2 Model Integration
- Download LFM2-700M-GGUF Q6_K from HuggingFace
- Install Core ML conversion tools (coremltools, transformers)
- Convert GGUF format to Core ML (.mlmodel)
- Add 612MB model to iOS app bundle
- Create LFM2Service.swift wrapper for model inference
- Test basic embedding generation functionality

#### Week 2: ObjectBox Database Setup
- Add ObjectBox Swift dependency via SPM
- Design RegulationEmbedding schema (vector + metadata)
- Implement VectorDatabase.swift service layer
- Create basic vector storage and retrieval operations
- Test similarity search with sample data
- Optimize database configuration for mobile performance

**Deliverables**: LFM2 model generating embeddings + ObjectBox storing/searching vectors

### Phase 2: Core Processing Engine (Weeks 3-4)
**Goal**: Build regulation processing pipeline

#### Week 3: Regulation Processing Pipeline
- Enhance existing regulationParser.ts for production use
- Implement intelligent text chunking (preserve section boundaries, max 512 tokens)
- Create RegulationProcessor.swift coordination service
- Add metadata extraction (regulation number, section, title, last updated)
- Build batch embedding generation with concurrency control
- Add processing progress tracking and error handling

#### Week 4: Initial Search Capability
- Implement VectorSearchService.swift for semantic search
- Create search result ranking and presentation logic
- Add query preprocessing and optimization
- Build basic search UI integration
- Test search accuracy with known regulation queries
- Optimize search performance for sub-second response

**Deliverables**: Complete HTML → embeddings → search pipeline working end-to-end

### Phase 3: Auto-Update System (Weeks 5-6)
**Goal**: Implement intelligent synchronization

#### Week 5: GitHub API Integration
- Create RegulationUpdateService.swift with GitHub API integration
- Implement file comparison logic (timestamps, hashes, content changes)
- Add incremental download system (fetch only changed files)
- Build update detection and scheduling system
- Add error handling, retry logic, and graceful degradation
- Test with GSA-Acquisition-FAR repository

#### Week 6: Background Processing
- Implement iOS Background App Refresh integration
- Add background processing of regulation updates
- Create update notification system ("47 regulations updated")
- Build update conflict resolution (handle regulation renames/moves)
- Add manual refresh capability with progress tracking
- Test auto-update reliability and performance

**Deliverables**: Automatic regulation updates working reliably in background

### Phase 4: Advanced Features (Weeks 7-8)
**Goal**: Personal repositories and optimization

#### Week 7: Personal Repository Support
- Implement GitHub OAuth authentication flow
- Create repository selection and validation UI
- Add custom repository processing (same pipeline as official)
- Implement data isolation (separate ObjectBox namespaces)
- Create unified search interface across all sources
- Add repository management (add/remove, refresh tokens)

#### Week 8: Performance Optimization
- Optimize model loading and memory usage patterns
- Improve search performance (indexing, caching, query optimization)
- Add processing analytics and performance monitoring
- Implement vector database cleanup and maintenance
- Create backup and restore functionality
- Conduct comprehensive performance testing

**Deliverables**: Personal repository support + optimized performance

### Phase 5: Integration & Polish (Weeks 9-10)
**Goal**: Complete LLM integration and production readiness

#### Week 9: LLM Integration
- Integrate search results with existing LLM chat interface
- Implement context injection for regulation-aware responses
- Add citation formatting and source attribution
- Create intelligent query preprocessing
- Build result ranking and presentation optimization
- Test complete workflow: search → results → LLM analysis

#### Week 10: Production Polish
- Complete UI/UX integration with existing AIKO interface
- Add comprehensive error handling and user feedback
- Implement analytics and usage tracking
- Create user onboarding flow for initial setup
- Conduct final testing and performance validation
- Prepare for App Store submission

**Deliverables**: Production-ready GraphRAG system integrated with AIKO

---

## 📊 Success Metrics & Validation

### Adoption Metrics
- **Setup Completion**: 90%+ users complete initial regulation database setup
- **Regular Usage**: Average 10+ regulation searches per user per week
- **Feature Discovery**: 80%+ users try personal repository functionality
- **Retention**: 85%+ monthly active usage after 3 months

### Performance Metrics
- **Search Speed**: Sub-second response times achieved for 95%+ queries
- **Search Accuracy**: User satisfaction > 4.5/5 for search relevance
- **System Reliability**: 99.9% uptime for search functionality
- **Update Success**: 98%+ successful auto-update completion rate

### User Value Metrics
- **Time Savings**: 80%+ reduction in regulation research time vs manual methods
- **User Satisfaction**: Overall product rating > 4.6/5 in App Store reviews
- **Expert Validation**: 90%+ accuracy validation from regulation experts
- **Business Impact**: Measurable improvement in procurement process efficiency

### Technical Performance
- **Response Latency**: Average search response < 0.8 seconds
- **Embedding Quality**: Semantic similarity scores > 0.85 for relevant matches
- **Memory Efficiency**: Average memory usage < 150MB during normal operation
- **Battery Impact**: < 5% additional battery drain per hour of active use

---

## ⚠️ Risk Assessment & Mitigation

### High-Risk Areas (Consensus-Identified)

#### 1. LFM2 Core ML Integration
**Risk**: Model conversion or iOS integration fails  
**Probability**: Medium  
**Impact**: High (blocks entire feature)  
**Mitigation**: 
- Early prototyping with model conversion
- Alternative model evaluation (backup options)
- iOS Core ML expert consultation
- Incremental integration testing

#### 2. Auto-Update System Complexity
**Risk**: Background updates fail or corrupt data  
**Probability**: Medium  
**Impact**: Medium (feature degradation)  
**Mitigation**:
- Robust error handling and rollback mechanisms
- Incremental update design (not full replacement)
- Comprehensive testing with various network conditions
- Manual update fallback option

### Medium-Risk Areas

#### 3. Search Accuracy and Relevance
**Risk**: Semantic search produces poor results  
**Probability**: Low-Medium  
**Impact**: High (user dissatisfaction)  
**Mitigation**:
- Extensive testing with regulation experts
- Iterative improvement based on user feedback
- Tunable similarity thresholds
- Hybrid search (semantic + keyword fallback)

#### 4. Performance on Older Devices
**Risk**: Slow performance on older iPhones  
**Probability**: Medium  
**Impact**: Medium (limited user base impact)  
**Mitigation**:
- Performance testing across device generations
- Progressive model loading strategies
- Graceful degradation for older hardware
- Clear minimum system requirements

### Low-Risk Areas

#### 5. User Adoption
**Risk**: Users don't adopt semantic search  
**Probability**: Low (consensus indicates high value)  
**Impact**: Medium (business impact)  
**Mitigation**:
- User-centric design and onboarding
- Clear value demonstration
- Integration with existing workflows
- Progressive feature rollout

---

## 🎯 Integration with Project Tasks

### Current Project Status
- **Overall Progress**: 77% complete (20/26 tasks)
- **Phase**: Currently completing Phase 4 (Document Scanner)
- **Next Phase**: Phase 5 GraphRAG implementation
- **Timeline**: GraphRAG aligns with final 10 weeks of project

### Integration Strategy
1. **Parallel Development**: Begin GraphRAG development alongside Phase 4 completion
2. **Incremental Integration**: Add GraphRAG components to existing TCA architecture
3. **Unified UI**: Integrate search interface with existing document and chat features
4. **Shared Services**: Leverage existing LLM integration for GraphRAG context

### Project Tasks Integration
This PRD and implementation plan should be integrated into Project_Tasks.md when Phase 5 development begins. The detailed tasks in this document will replace the current high-level Phase 5 placeholders with specific, actionable implementation steps.

---

## 📝 Validation & Approval

### Multi-Model Consensus Results
**VanillaIce Engine**: 6/7 models approved (85.7% consensus)  
**Duration**: 82.949 seconds analysis  
**Models Consulted**: 
- ✅ mistralai/codestral-2501 (code_specialist)
- ✅ codex-mini-latest (codegen)  
- ✅ qwen/qwen-2.5-coder-32b-instruct (code_generation)
- ✅ openai-o3 (advanced_reasoning)
- ✅ gemini-2.5-flash (fast_reasoning)
- ✅ moonshotai/kimi-k2 (fast_analysis)

### Key Consensus Findings
- **Technical Feasibility**: Confirmed viable for iOS deployment
- **User Value**: Strong market demand validated
- **Implementation Timeline**: Realistic for complexity level
- **Technology Choices**: Optimal selections confirmed
- **Success Probability**: High likelihood of delivering value

### Recommendation
**APPROVED FOR IMPLEMENTATION** - Proceed with Phase 5 GraphRAG development according to this validated plan.

---

**Document Prepared**: AI Development Team  
**Consensus Validation**: VanillaIce Multi-Model Engine  
**Next Review**: Upon Phase 5 implementation commencement  
**Status**: Ready for integration into Project_Tasks.md