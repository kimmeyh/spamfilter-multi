#!/usr/bin/env node

/**
 * Email Rule Tester MCP Server
 * 
 * Provides tools for testing and validating spam filter rules:
 * - Validate YAML rule files
 * - Test regex patterns
 * - Simulate rule evaluation
 * - Check for performance issues
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import fs from 'fs/promises';
import path from 'path';
import YAML from 'yaml';

const server = new Server(
  {
    name: 'email-rule-tester',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Tool definitions
const TOOLS = [
  {
    name: 'validate_rules_yaml',
    description: 'Validate rules.yaml file for syntax, schema compliance, and regex patterns',
    inputSchema: {
      type: 'object',
      properties: {
        file_path: {
          type: 'string',
          description: 'Path to rules.yaml file',
        },
      },
      required: ['file_path'],
    },
  },
  {
    name: 'validate_safe_senders',
    description: 'Validate rules_safe_senders.yaml file for syntax and patterns',
    inputSchema: {
      type: 'object',
      properties: {
        file_path: {
          type: 'string',
          description: 'Path to rules_safe_senders.yaml file',
        },
      },
      required: ['file_path'],
    },
  },
  {
    name: 'test_regex_pattern',
    description: 'Test a regex pattern against sample email headers',
    inputSchema: {
      type: 'object',
      properties: {
        pattern: {
          type: 'string',
          description: 'Regex pattern to test',
        },
        test_strings: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of strings to test against',
        },
        check_performance: {
          type: 'boolean',
          description: 'Run performance test (1000 iterations)',
          default: false,
        },
      },
      required: ['pattern', 'test_strings'],
    },
  },
  {
    name: 'simulate_rule_evaluation',
    description: 'Simulate how an email would be evaluated against rules',
    inputSchema: {
      type: 'object',
      properties: {
        rules_file: {
          type: 'string',
          description: 'Path to rules.yaml',
        },
        safe_senders_file: {
          type: 'string',
          description: 'Path to rules_safe_senders.yaml',
        },
        email: {
          type: 'object',
          properties: {
            from: { type: 'string' },
            subject: { type: 'string' },
            body: { type: 'string' },
            headers: { type: 'object' },
          },
          required: ['from', 'subject'],
        },
      },
      required: ['rules_file', 'email'],
    },
  },
];

// Helper: Validate regex pattern
function validateRegexPattern(pattern) {
  try {
    new RegExp(pattern, 'i');
    
    // Check for dangerous patterns (catastrophic backtracking)
    const dangerousPatterns = [
      { regex: /(\.\*){2,}/, desc: 'Multiple .* in sequence' },
      { regex: /\(\.\*\+/, desc: '.* followed by +' },
      { regex: /\(\.\+\)\*/, desc: '(.+)* pattern' },
      { regex: /\(\[.*\]\+\)\*/, desc: '([...]+)* pattern' },
    ];
    
    const warnings = [];
    for (const { regex, desc } of dangerousPatterns) {
      if (regex.test(pattern)) {
        warnings.push(`Performance warning: ${desc} (catastrophic backtracking risk)`);
      }
    }
    
    return { valid: true, warnings };
  } catch (error) {
    return { valid: false, error: error.message };
  }
}

// Helper: Test regex performance
function testRegexPerformance(pattern, testStrings) {
  const regex = new RegExp(pattern, 'i');
  const iterations = 1000;
  
  let totalTime = 0;
  for (const testStr of testStrings) {
    const start = process.hrtime.bigint();
    for (let i = 0; i < iterations; i++) {
      regex.test(testStr);
    }
    const end = process.hrtime.bigint();
    totalTime += Number(end - start) / 1000000; // Convert to ms
  }
  
  const avgTime = totalTime / (testStrings.length * iterations);
  
  return {
    avgTimeMs: avgTime,
    rating: avgTime > 1 ? 'slow' : avgTime > 0.1 ? 'acceptable' : 'fast',
  };
}

// Tool handlers
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools: TOOLS };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  
  try {
    switch (name) {
      case 'validate_rules_yaml': {
        const content = await fs.readFile(args.file_path, 'utf-8');
        const parsed = YAML.parse(content);
        
        const errors = [];
        const warnings = [];
        
        // Schema validation
        if (!parsed.version) errors.push('Missing "version" field');
        if (!parsed.rules) errors.push('Missing "rules" field');
        
        // Validate each rule
        if (parsed.rules && Array.isArray(parsed.rules)) {
          for (const [index, rule] of parsed.rules.entries()) {
            if (!rule.name) errors.push(`Rule ${index}: Missing "name" field`);
            if (!rule.conditions) errors.push(`Rule ${index}: Missing "conditions" field`);
            
            // Validate regex patterns in conditions
            if (rule.conditions) {
              for (const field of ['from', 'subject', 'body', 'header']) {
                if (rule.conditions[field]) {
                  for (const pattern of rule.conditions[field]) {
                    const validation = validateRegexPattern(pattern);
                    if (!validation.valid) {
                      errors.push(`Rule ${index} (${rule.name}): Invalid ${field} pattern: ${validation.error}`);
                    }
                    if (validation.warnings) {
                      warnings.push(...validation.warnings.map(w => `Rule ${index} (${rule.name}): ${w}`));
                    }
                  }
                }
              }
            }
          }
        }
        
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify({
                valid: errors.length === 0,
                errors,
                warnings,
                ruleCount: parsed.rules?.length || 0,
              }, null, 2),
            },
          ],
        };
      }
      
      case 'validate_safe_senders': {
        const content = await fs.readFile(args.file_path, 'utf-8');
        const parsed = YAML.parse(content);
        
        const errors = [];
        const warnings = [];
        
        if (!parsed.safe_senders) {
          errors.push('Missing "safe_senders" field');
        } else if (!Array.isArray(parsed.safe_senders)) {
          errors.push('"safe_senders" must be an array');
        } else {
          const patterns = new Set();
          for (const [index, pattern] of parsed.safe_senders.entries()) {
            // Check for duplicates
            if (patterns.has(pattern)) {
              warnings.push(`Duplicate pattern at index ${index}: ${pattern}`);
            }
            patterns.add(pattern);
            
            // Validate regex
            const validation = validateRegexPattern(pattern);
            if (!validation.valid) {
              errors.push(`Invalid pattern at index ${index}: ${validation.error}`);
            }
            if (validation.warnings) {
              warnings.push(...validation.warnings.map(w => `Pattern ${index}: ${w}`));
            }
          }
        }
        
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify({
                valid: errors.length === 0,
                errors,
                warnings,
                patternCount: parsed.safe_senders?.length || 0,
              }, null, 2),
            },
          ],
        };
      }
      
      case 'test_regex_pattern': {
        const { pattern, test_strings, check_performance } = args;
        
        const validation = validateRegexPattern(pattern);
        if (!validation.valid) {
          return {
            content: [
              {
                type: 'text',
                text: JSON.stringify({ error: `Invalid regex: ${validation.error}` }, null, 2),
              },
            ],
          };
        }
        
        const regex = new RegExp(pattern, 'i');
        const results = test_strings.map(str => ({
          string: str,
          matches: regex.test(str),
          matchDetails: regex.exec(str),
        }));
        
        const performance = check_performance ? testRegexPerformance(pattern, test_strings) : null;
        
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify({
                pattern,
                valid: true,
                warnings: validation.warnings,
                results,
                performance,
                matchCount: results.filter(r => r.matches).length,
                totalCount: results.length,
              }, null, 2),
            },
          ],
        };
      }
      
      case 'simulate_rule_evaluation': {
        // Load rules and safe senders
        const rulesContent = await fs.readFile(args.rules_file, 'utf-8');
        const rules = YAML.parse(rulesContent);
        
        let safeSenders = [];
        if (args.safe_senders_file) {
          const safeSendersContent = await fs.readFile(args.safe_senders_file, 'utf-8');
          const safeSendersData = YAML.parse(safeSendersContent);
          safeSenders = safeSendersData.safe_senders || [];
        }
        
        const { email } = args;
        
        // Check safe senders first
        const isSafeSender = safeSenders.some(pattern => {
          const regex = new RegExp(pattern, 'i');
          return regex.test(email.from);
        });
        
        if (isSafeSender) {
          return {
            content: [
              {
                type: 'text',
                text: JSON.stringify({
                  result: 'safe_sender',
                  message: 'Email from safe sender - no rules applied',
                }, null, 2),
              },
            ],
          };
        }
        
        // Evaluate rules
        for (const rule of rules.rules || []) {
          if (rule.enabled === 'False') continue;
          
          let matched = false;
          const matchedConditions = [];
          
          // Check conditions
          if (rule.conditions) {
            const conditionType = rule.conditions.type || 'OR';
            
            // Check from
            if (rule.conditions.from) {
              for (const pattern of rule.conditions.from) {
                const regex = new RegExp(pattern, 'i');
                if (regex.test(email.from)) {
                  matchedConditions.push({ field: 'from', pattern });
                }
              }
            }
            
            // Check subject
            if (rule.conditions.subject) {
              for (const pattern of rule.conditions.subject) {
                const regex = new RegExp(pattern, 'i');
                if (regex.test(email.subject)) {
                  matchedConditions.push({ field: 'subject', pattern });
                }
              }
            }
            
            // Evaluate based on condition type
            matched = conditionType === 'OR' 
              ? matchedConditions.length > 0
              : matchedConditions.length === Object.keys(rule.conditions).filter(k => k !== 'type').length;
          }
          
          if (matched) {
            return {
              content: [
                {
                  type: 'text',
                  text: JSON.stringify({
                    result: 'rule_matched',
                    rule: rule.name,
                    matchedConditions,
                    actions: rule.actions,
                  }, null, 2),
                },
              ],
            };
          }
        }
        
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify({
                result: 'no_match',
                message: 'No rules matched this email',
              }, null, 2),
            },
          ],
        };
      }
      
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({ error: error.message }, null, 2),
        },
      ],
      isError: true,
    };
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Email Rule Tester MCP server running on stdio');
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});
