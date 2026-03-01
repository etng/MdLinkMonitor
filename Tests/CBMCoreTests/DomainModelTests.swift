import Testing
@testable import CBMCore

@Test
func markdownLinkExtractionSingle() {
    let input = "Use [Repo](https://github.com/apple/swift) now"
    let links = MarkdownLinkExtractor.extract(from: input)

    #expect(links.count == 1)
    #expect(links[0] == MarkdownLink(label: "Repo", url: "https://github.com/apple/swift"))
}

@Test
func markdownLinkExtractionMultiple() {
    let input = "[A](https://github.com/o1/r1) and [B](https://github.com/o2/r2)"
    let links = MarkdownLinkExtractor.extract(from: input)

    #expect(links.count == 2)
    #expect(links[1].label == "B")
}

@Test
func githubRepoParsesAndNormalizes() {
    let parsed = GitHubRepositoryParser.parse(from: "https://github.com/owner/repo.git?tab=readme#top")

    #expect(parsed?.owner == "owner")
    #expect(parsed?.name == "repo")
    #expect(parsed?.host == "github.com")
    #expect(parsed?.canonicalURL == "https://github.com/owner/repo")
    #expect(parsed?.cloneURL == "https://github.com/owner/repo.git")
    #expect(parsed?.dailyDedupKey == "github.com/owner/repo")
}

@Test
func githubRepoRejectsNonRepoOrPath() {
    #expect(GitHubRepositoryParser.parse(from: "https://github.com/owner") == nil)
    #expect(GitHubRepositoryParser.parse(from: "https://github.com/owner/repo/issues") == nil)
    #expect(GitHubRepositoryParser.parse(from: "http://github.com/owner/repo") == nil)
    #expect(GitHubRepositoryParser.parse(from: "https://example.com/owner/repo") == nil)
}

@Test
func genericGitRepositoryParserSupportsGitLab() {
    let parsed = GitRepositoryParser.parse(
        from: "https://gitlab.com/group/project/-/issues/1",
        allowedDomains: ["github.com", "gitlab.com"]
    )
    #expect(parsed == nil)

    let repoParsed = GitRepositoryParser.parse(
        from: "https://gitlab.com/group/project?tab=readme#x",
        allowedDomains: ["github.com", "gitlab.com"]
    )
    #expect(repoParsed?.host == "gitlab.com")
    #expect(repoParsed?.canonicalURL == "https://gitlab.com/group/project")
}

@Test
func markdownTaskLineBuilderWorks() {
    let line = MarkdownTaskLineBuilder.makeLine(label: "Swift", repositoryURL: "https://github.com/apple/swift")
    #expect(line == "* [ ] [Swift](https://github.com/apple/swift)")
}
